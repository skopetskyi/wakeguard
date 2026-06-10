import AppKit
import WakeGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Single source of truth for limits: pre-flight, monitor, and controller
    // must never read diverging values.
    private let limits = SafetyLimits()
    lazy var controller = SessionController(spawner: CaffeinateSpawner(),
                                            leaseStore: LeaseStore(),
                                            limits: limits)
    private lazy var safetyMonitor = SafetyMonitor(controller: controller, limits: limits)
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(active: false)

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

    func sleepDisplayNow() {
        Shell.run("/usr/bin/pmset", ["displaysleepnow"])
    }

    // MARK: - UI state

    func sessionStateChanged() {
        let active = controller.activeSession != nil
        NSApp.setActivationPolicy(active ? .regular : .accessory)
        if !active { NSApp.dockTile.badgeLabel = nil }
        updateIcon(active: active)
        rebuildMenu()
    }

    private func updateIcon(active: Bool) {
        let symbol = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        statusItem.button?.image = NSImage(systemSymbolName: symbol,
                                           accessibilityDescription: "WakeGuard")
    }

    private func refreshCountdown() {
        guard let session = controller.activeSession else { return }
        let remaining = max(0, Int(session.endsAt.timeIntervalSinceNow))
        NSApp.dockTile.badgeLabel = String(format: "%d:%02d", remaining / 3600, (remaining % 3600) / 60)
    }

    func rebuildMenu() {
        statusItem.menu = MenuBuilder.build(for: self)
    }
}
