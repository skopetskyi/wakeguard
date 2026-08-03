import AppKit
import CoreGraphics
import WakeGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Single source of truth for limits: pre-flight, monitor, and controller
    // must never read diverging values.
    private let limits = SafetyLimits()
    lazy var controller = SessionController(spawner: CaffeinateSpawner(),
                                            leaseStore: LeaseStore(),
                                            limits: limits)
    // Concrete emitter is held so the "Activity Method" menu can switch the
    // mechanism (volume / mouse / F-key) live; the simulator drives it.
    let activityEmitter = ConfigurableActivityEmitter()
    lazy var activitySimulator = ActivitySimulator(emitter: activityEmitter)
    private lazy var safetyMonitor = SafetyMonitor(controller: controller, limits: limits)
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private static let activityMethodDefaultsKey = "activityMethodID"

    // Presence keep-awake: while Simulate Activity is on, a `caffeinate -i -w`
    // process holds a system-sleep assertion (needs no Accessibility permission),
    // so the Mac stays awake even if the volume tap is ever filtered.
    private let presenceSpawner = CaffeinateSpawner()
    private var presenceKeepAwake: CaffeinateProcess?

    // System sleep timer (independent of Simulate Activity): when set, the Mac is
    // put to sleep at the deadline. `sleepTimerEndsAt` is nil when no timer runs.
    private(set) var sleepTimerEndsAt: Date?
    private var sleepTimer: Timer?

    // Active hours: the daily local-time window in which activity simulation may
    // run. A simulation started (or left running) outside it is stopped by the
    // enforcement timer, so the Mac never stays awake overnight.
    private(set) var activeHours = ActiveHours()
    private var activeHoursTimer: Timer?
    /// How often the window is re-checked while simulation runs.
    private static let activeHoursCheckInterval: TimeInterval = 60
    private static let activeHoursEnabledKey = "activeHoursEnabled"
    private static let activeHoursStartKey = "activeHoursStartHour"
    private static let activeHoursEndKey = "activeHoursEndHour"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always a regular app: the Dock icon is present whenever WakeGuard runs.
        NSApp.setActivationPolicy(.regular)
        loadActivityMethod()
        loadActiveHours()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshStatusIcon()

        controller.onSessionEnded = { [weak self] reason in
            Notify.send(title: "WakeGuard", body: "Session ended: \(reason)")
            self?.sessionStateChanged()
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        safetyMonitor.start()
        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop(reason: "App quit")
        activitySimulator.stop()
        stopPresenceKeepAwake()
    }

    // MARK: - Session actions (called from MenuBuilder)

    func startSession(minutes: Int, displayPolicy: SessionConfig.DisplayPolicy,
                      lidPolicy: SessionConfig.LidPolicy) {
        if lidPolicy == .stayAwakeWhenClosed {
            if ProcessInfo.processInfo.thermalState == .critical {
                Notify.send(title: "WakeGuard",
                            body: "Refusing closed-lid mode: thermal state is critical. Let the Mac cool down first.")
                return
            }
            let battery = BatteryStatusParser.current()
            if battery.source == .battery {
                guard let percent = battery.percent, percent >= limits.softBatteryPercent else {
                    Notify.send(title: "WakeGuard",
                                body: "Refusing closed-lid mode: battery too low or unreadable. Plug in first.")
                    return
                }
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode on battery (\(percent)%). Will auto-stop below \(limits.softBatteryPercent)%.")
            }
        }
        // Closed-lid display: keep the display on only in clamshell (an external
        // display is connected — you're using it); with a bare shut lid there's
        // nothing to show, so let the display sleep.
        var effectiveDisplay = displayPolicy
        if lidPolicy == .stayAwakeWhenClosed {
            effectiveDisplay = Self.hasExternalDisplay() ? .keepOn : .allowOff
        }
        let config = SessionConfig(duration: TimeInterval(minutes * 60),
                                   displayPolicy: effectiveDisplay, lidPolicy: lidPolicy)
        do {
            try controller.start(config)
            safetyMonitor.sessionDidStart()
            verifyClosedLidTookEffect()
            if lidPolicy == .stayAwakeWhenClosed {
                let displayNote = effectiveDisplay == .keepOn
                    ? "External display kept on."
                    : "Display may sleep."
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode active for \(minutes) min. Lid can be closed. \(displayNote)")
            }
            sessionStateChanged()
        } catch {
            Notify.send(title: "WakeGuard", body: "Failed to start: \(error.localizedDescription)")
        }
    }

    func stopSession() {
        controller.stop(reason: "Stopped from menu")
    }

    /// Closed-lid verification: 8s after start (daemon polls every 5s), confirm
    /// the system actually has SleepDisabled=1. If not, the lid is NOT safe to close.
    private func verifyClosedLidTookEffect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self,
                  let session = self.controller.activeSession,
                  session.config.lidPolicy == .stayAwakeWhenClosed else { return }
            if !SystemStatus.probe().sleepDisabled {
                Notify.send(title: "WakeGuard — NOT SAFE TO CLOSE LID",
                            body: "disablesleep did not engage. Is wakeguardd installed? (scripts/install-daemon.sh)")
            }
        }
    }

    func sleepDisplayNow() {
        Shell.run("/usr/bin/pmset", ["displaysleepnow"])
    }

    /// True if any active display is NOT the built-in panel — i.e. an external
    /// monitor is connected (so closing the lid means clamshell, not "no display").
    /// Handles the case where the Mac is already in clamshell at start (built-in
    /// off), which a simple screen-count check would miss.
    private static func hasExternalDisplay() -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return false }
        return displays.contains { CGDisplayIsBuiltin($0) == 0 }
    }

    // MARK: - Presence keep-awake (power assertion)

    /// Spawn `caffeinate -i -w <app-pid>` to hold a system-sleep assertion while
    /// Simulate Activity is on. `-w` ties it to this app, so it dies with us.
    func startPresenceKeepAwake() {
        guard presenceKeepAwake == nil else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        presenceKeepAwake = try? presenceSpawner.spawnCaffeinate(arguments: ["-i", "-w", String(pid)])
    }

    func stopPresenceKeepAwake() {
        presenceKeepAwake?.terminate()
        presenceKeepAwake = nil
    }

    // MARK: - Activity simulation (presence, on/off)

    func startActivitySimulation() {
        MenuBuilder.simulateActivity = true
        startPresenceKeepAwake()
        activitySimulator.start()
        startActiveHoursEnforcement()
        if activeHours.isEnabled && !activeHours.contains(Date()) {
            // Started outside the window: allowed, but the enforcement timer will
            // shut it down shortly so it can't run overnight.
            Notify.send(title: "WakeGuard",
                        body: "Heads up: it's outside your active hours (\(activeHours.displayLabel)) — activity simulation will stop again within a minute.")
        }
        if AccessibilityPermission.isTrusted {
            Notify.send(title: "WakeGuard",
                        body: "Activity simulation on — the volume HUD will blip each minute (presence stays active).")
        } else {
            // Without Accessibility, macOS silently drops the volume blip, so
            // presence won't hold. Surface it and pop the grant dialog. (The Mac
            // still stays awake via the assertion.)
            AccessibilityPermission.promptIfNeeded()
            Notify.send(title: "WakeGuard needs Accessibility",
                        body: "Grant WakeGuard in System Settings → Privacy & Security → Accessibility, then the volume blip works. After any rebuild you must re-grant it.")
        }
        refreshStatusIcon()
        rebuildMenu()
    }

    // MARK: - Active hours (local-time window for activity simulation)

    private func loadActiveHours() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.activeHoursEnabledKey) != nil else { return }
        activeHours = ActiveHours(isEnabled: defaults.bool(forKey: Self.activeHoursEnabledKey),
                                  startHour: defaults.integer(forKey: Self.activeHoursStartKey),
                                  endHour: defaults.integer(forKey: Self.activeHoursEndKey))
    }

    private func saveActiveHours() {
        let defaults = UserDefaults.standard
        defaults.set(activeHours.isEnabled, forKey: Self.activeHoursEnabledKey)
        defaults.set(activeHours.startHour, forKey: Self.activeHoursStartKey)
        defaults.set(activeHours.endHour, forKey: Self.activeHoursEndKey)
    }

    /// Menu actions: toggle the window on/off and set its bounds. Changing the
    /// window re-checks immediately, so narrowing it stops a running simulation.
    func setActiveHoursEnabled(_ enabled: Bool) {
        activeHours.isEnabled = enabled
        saveActiveHours()
        enforceActiveHours()
        rebuildMenu()
    }

    func setActiveHoursStart(_ hour: Int) {
        activeHours = ActiveHours(isEnabled: activeHours.isEnabled,
                                  startHour: hour, endHour: activeHours.endHour)
        saveActiveHours()
        enforceActiveHours()
        rebuildMenu()
    }

    func setActiveHoursEnd(_ hour: Int) {
        activeHours = ActiveHours(isEnabled: activeHours.isEnabled,
                                  startHour: activeHours.startHour, endHour: hour)
        saveActiveHours()
        enforceActiveHours()
        rebuildMenu()
    }

    /// Runs while simulation is active; stops it once the local clock leaves the
    /// window (checked every minute, so it never runs on past the window's end).
    private func startActiveHoursEnforcement() {
        activeHoursTimer?.invalidate()
        let timer = Timer(timeInterval: Self.activeHoursCheckInterval, repeats: true) { [weak self] _ in
            self?.enforceActiveHours()
        }
        RunLoop.main.add(timer, forMode: .common)
        activeHoursTimer = timer
    }

    private func stopActiveHoursEnforcement() {
        activeHoursTimer?.invalidate()
        activeHoursTimer = nil
    }

    /// Stop activity simulation if the current local time is outside the window.
    private func enforceActiveHours() {
        guard MenuBuilder.simulateActivity else { return }
        guard !activeHours.contains(Date()) else { return }
        stopActivitySimulation()
        Notify.send(title: "WakeGuard",
                    body: "Outside active hours (\(activeHours.displayLabel)) — activity simulation stopped.")
    }

    /// Restore the saved activity method (or the default) into emitter + menu.
    private func loadActivityMethod() {
        let savedID = UserDefaults.standard.string(forKey: Self.activityMethodDefaultsKey)
        let method = savedID.flatMap(PresenceMethods.method(withID:)) ?? PresenceMethods.default
        MenuBuilder.activityMethodID = method.id
        activityEmitter.method = method
    }

    /// Called from the "Activity Method" submenu. Persists the choice; if
    /// simulation is running, restarts it so the new method applies immediately.
    func selectActivityMethod(id: String) {
        guard let method = PresenceMethods.method(withID: id) else { return }
        MenuBuilder.activityMethodID = method.id
        activityEmitter.method = method
        UserDefaults.standard.set(method.id, forKey: Self.activityMethodDefaultsKey)
        if MenuBuilder.simulateActivity {
            activitySimulator.stop()
            activitySimulator.start()
        }
        rebuildMenu()
    }

    /// "Test (blip now)" — fire one event and report whether it can reach the
    /// system, so a missing permission is obvious instead of a silent no-op.
    func testActivityBlip() {
        activitySimulator.emitOnce()
        if AccessibilityPermission.isTrusted {
            Notify.send(title: "WakeGuard test",
                        body: "Sent a volume blip — you should have just seen the volume HUD flash.")
        } else {
            AccessibilityPermission.promptIfNeeded()
            Notify.send(title: "WakeGuard test — blocked",
                        body: "No Accessibility permission, so the blip is filtered. Grant WakeGuard in System Settings → Privacy & Security → Accessibility, then test again.")
        }
    }

    /// Stop the presence loop + keep-awake assertion. Silent (callers notify).
    func stopActivitySimulation() {
        guard MenuBuilder.simulateActivity else { return }
        MenuBuilder.simulateActivity = false
        activitySimulator.stop()
        stopPresenceKeepAwake()
        stopActiveHoursEnforcement()
        refreshStatusIcon()
        rebuildMenu()
    }

    // MARK: - System sleep timer (independent feature)

    /// Schedule the Mac to sleep after `duration` seconds, with a visible
    /// countdown. Replaces any existing timer.
    func startSleepTimer(duration: TimeInterval) {
        sleepTimer?.invalidate()
        sleepTimerEndsAt = Date().addingTimeInterval(duration)
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.fireSleepTimer()
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
        let mins = Int(duration / 60)
        let label = mins < 60 ? "\(mins) min" : "\(mins / 60)h\(mins % 60 == 0 ? "" : " \(mins % 60)m")"
        Notify.send(title: "WakeGuard", body: "Sleep timer set — the Mac will sleep in \(label).")
        refreshStatusIcon()
        rebuildMenu()
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate(); sleepTimer = nil
        sleepTimerEndsAt = nil
        Notify.send(title: "WakeGuard", body: "Sleep timer cancelled.")
        refreshStatusIcon()
        rebuildMenu()
    }

    private func fireSleepTimer() {
        sleepTimer?.invalidate(); sleepTimer = nil
        sleepTimerEndsAt = nil
        // Wind down keep-awake intent so nothing fights the sleep or re-wakes it.
        stopActivitySimulation()
        controller.stop(reason: "Sleep timer")
        Notify.send(title: "WakeGuard", body: "Sleep timer elapsed — sleeping now.")
        Shell.run("/usr/bin/pmset", ["sleepnow"])
    }

    // MARK: - UI state

    func sessionStateChanged() {
        let active = controller.activeSession != nil
        // The Dock icon is always shown; only the countdown badge is gated on a
        // running session — clear it the moment the session ends.
        if !active { NSApp.dockTile.badgeLabel = nil }
        refreshStatusIcon()
        rebuildMenu()
    }

    /// Recomputes and applies the status item, reflecting both the keep-awake
    /// session state (cup fill vs outline) and the activity-simulation state
    /// (a green "● Active" label beside the icon).
    ///
    /// A status-bar template image is drawn in the menu bar's own adaptive
    /// colour and ignores `contentTintColor`, so the activity mode is surfaced
    /// with a coloured title label — which renders reliably — rather than by
    /// tinting the icon.
    func refreshStatusIcon() {
        guard let button = statusItem.button else { return }
        let sessionActive = controller.activeSession != nil
        let simActive = MenuBuilder.simulateActivity
        let symbol = sessionActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let a11y = simActive ? "WakeGuard — simulating activity" : "WakeGuard"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: a11y)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        applyStatusTitle()
    }

    /// The menu-bar label: green **"● Active"** while simulating activity, plus an
    /// orange **"💤 H:MM:SS"** countdown while a sleep timer runs. Both render
    /// together and update every second so each state is obvious at a glance.
    private func applyStatusTitle() {
        guard let button = statusItem.button else { return }
        let font = NSFont.menuBarFont(ofSize: 0)
        let title = NSMutableAttributedString()
        if MenuBuilder.simulateActivity {
            title.append(NSAttributedString(string: " ● Active",
                attributes: [.foregroundColor: NSColor.systemGreen, .font: font]))
        }
        if let endsAt = sleepTimerEndsAt {
            let r = max(0, Int(endsAt.timeIntervalSinceNow))
            let s = String(format: " 💤 %d:%02d:%02d", r / 3600, (r % 3600) / 60, r % 60)
            title.append(NSAttributedString(string: s,
                attributes: [.foregroundColor: NSColor.systemOrange, .font: font]))
        }
        button.attributedTitle = title
    }

    private func refreshCountdown() {
        if let session = controller.activeSession {
            let remaining = max(0, Int(session.endsAt.timeIntervalSinceNow))
            NSApp.dockTile.badgeLabel = String(format: "%d:%02d", remaining / 3600, (remaining % 3600) / 60)
        }
        // Keep the menu-bar countdowns live each second.
        applyStatusTitle()
    }

    func rebuildMenu() {
        statusItem.menu = MenuBuilder.build(for: self)
    }
}
