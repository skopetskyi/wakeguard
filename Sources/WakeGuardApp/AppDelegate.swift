import AppKit
import WakeGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Single source of truth for limits: pre-flight, monitor, and controller
    // must never read diverging values.
    private let limits = SafetyLimits()
    lazy var controller = SessionController(spawner: CaffeinateSpawner(),
                                            leaseStore: LeaseStore(),
                                            limits: limits)
    let activitySimulator = ActivitySimulator(emitter: VolumeTapActivityEmitter())
    private lazy var safetyMonitor = SafetyMonitor(controller: controller, limits: limits)
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?

    // Presence keep-awake: while Simulate Activity is on, a `caffeinate -i -w`
    // process holds a system-sleep assertion (needs no Accessibility permission),
    // so the Mac stays awake even if the volume tap is ever filtered.
    private let presenceSpawner = CaffeinateSpawner()
    private var presenceKeepAwake: CaffeinateProcess?

    // System sleep timer (independent of Simulate Activity): when set, the Mac is
    // put to sleep at the deadline. `sleepTimerEndsAt` is nil when no timer runs.
    private(set) var sleepTimerEndsAt: Date?
    private var sleepTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always a regular app: the Dock icon is present whenever WakeGuard runs.
        NSApp.setActivationPolicy(.regular)
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
        let config = SessionConfig(duration: TimeInterval(minutes * 60),
                                   displayPolicy: displayPolicy, lidPolicy: lidPolicy)
        do {
            try controller.start(config)
            safetyMonitor.sessionDidStart()
            verifyClosedLidTookEffect()
            if lidPolicy == .stayAwakeWhenClosed {
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode active for \(minutes) min. Lid can be closed.")
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
        if MenuBuilder.didHintActivityPermission {
            Notify.send(title: "WakeGuard",
                        body: "Activity simulation on — presence stays active (Slack/Teams).")
        } else {
            MenuBuilder.didHintActivityPermission = true
            Notify.send(title: "WakeGuard",
                        body: "Activity simulation on. The volume HUD blips each minute. If Slack/Teams still go idle, grant WakeGuard Accessibility access in System Settings → Privacy & Security.")
        }
        refreshStatusIcon()
        rebuildMenu()
    }

    /// Stop the presence loop + keep-awake assertion. Silent (callers notify).
    func stopActivitySimulation() {
        guard MenuBuilder.simulateActivity else { return }
        MenuBuilder.simulateActivity = false
        activitySimulator.stop()
        stopPresenceKeepAwake()
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
