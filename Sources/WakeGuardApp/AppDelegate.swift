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

    // Simulate-Activity duration ("sleep timer"). `activityEndsAt` is nil when off
    // or running indefinitely; the timer auto-stops at the deadline so the Mac can
    // sleep afterwards.
    private(set) var activityEndsAt: Date?
    private var activityEndTimer: Timer?

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

    // MARK: - Activity simulation (presence + sleep timer)

    /// Start Simulate Activity for `duration` seconds (nil = until turned off).
    /// Holds the keep-awake assertion, starts the volume-tap presence loop, and
    /// schedules an auto-stop at the deadline so the Mac can sleep afterwards.
    func startActivitySimulation(duration: TimeInterval?) {
        MenuBuilder.simulateActivity = true
        startPresenceKeepAwake()
        activitySimulator.start()

        activityEndTimer?.invalidate()
        if let duration {
            activityEndsAt = Date().addingTimeInterval(duration)
            let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                self?.stopActivitySimulation(reason: "Activity timer elapsed — the Mac can sleep now.")
            }
            RunLoop.main.add(timer, forMode: .common)
            activityEndTimer = timer
        } else {
            activityEndsAt = nil
        }

        if MenuBuilder.didHintActivityPermission {
            Notify.send(title: "WakeGuard", body: activityOnMessage(duration: duration))
        } else {
            MenuBuilder.didHintActivityPermission = true
            Notify.send(title: "WakeGuard",
                        body: "Activity simulation on. The volume HUD blips each minute. If Slack/Teams still go idle, grant WakeGuard Accessibility access in System Settings → Privacy & Security.")
        }
        refreshStatusIcon()
        rebuildMenu()
    }

    func stopActivitySimulation(reason: String) {
        guard MenuBuilder.simulateActivity else { return }
        MenuBuilder.simulateActivity = false
        activitySimulator.stop()
        stopPresenceKeepAwake()
        activityEndTimer?.invalidate(); activityEndTimer = nil
        activityEndsAt = nil
        Notify.send(title: "WakeGuard", body: reason)
        refreshStatusIcon()
        rebuildMenu()
    }

    private func activityOnMessage(duration: TimeInterval?) -> String {
        guard let duration else {
            return "Activity simulation on until you turn it off — presence stays active (Slack/Teams)."
        }
        let mins = Int(duration / 60)
        let label = mins < 60 ? "\(mins) min" : "\(mins / 60)h\(mins % 60 == 0 ? "" : " \(mins % 60)m")"
        return "Activity simulation on for \(label) — presence stays active (Slack/Teams)."
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
        applyActivityTitle()
    }

    /// The green menu-bar label: a live countdown while a timed activity
    /// simulation runs, "● Active" when indefinite, empty when off. Updated every
    /// second by `refreshCountdown` so the active state is obvious at a glance.
    private func applyActivityTitle() {
        guard let button = statusItem.button else { return }
        guard MenuBuilder.simulateActivity else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }
        let text: String
        if let endsAt = activityEndsAt {
            let r = max(0, Int(endsAt.timeIntervalSinceNow))
            text = String(format: " ● %d:%02d:%02d", r / 3600, (r % 3600) / 60, r % 60)
        } else {
            text = " ● Active"
        }
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: NSColor.systemGreen,
                         .font: NSFont.menuBarFont(ofSize: 0)])
    }

    private func refreshCountdown() {
        if let session = controller.activeSession {
            let remaining = max(0, Int(session.endsAt.timeIntervalSinceNow))
            NSApp.dockTile.badgeLabel = String(format: "%d:%02d", remaining / 3600, (remaining % 3600) / 60)
        }
        // Keep the green menu-bar countdown live each second.
        applyActivityTitle()
    }

    func rebuildMenu() {
        statusItem.menu = MenuBuilder.build(for: self)
    }
}
