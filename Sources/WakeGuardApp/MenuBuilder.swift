import AppKit
import WakeGuardCore

enum MenuBuilder {
    static let durationsMinutes = [15, 30, 60, 120, 240, 480]

    // Mode toggles persist across menu rebuilds.
    static var allowDisplayOff = false
    static var closedLidMode = false
    static var simulateActivity = false

    // Currently selected presence method id (loaded from / saved to UserDefaults
    // by AppDelegate). Drives the "Activity Method" submenu checkmark.
    static var activityMethodID = PresenceMethods.default.id

    static func build(for app: AppDelegate) -> NSMenu {
        let menu = NSMenu()

        // ── Keep Awake ──────────────────────────────────────────────────
        menu.addItem(sectionHeader("Keep Awake"))
        if let session = app.controller.activeSession {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let status = NSMenuItem(title: "Awake until \(formatter.string(from: session.endsAt))",
                                    action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            let probe = SystemStatus.probe()
            let line = probe.menuLine(expectClosedLid: session.config.lidPolicy == .stayAwakeWhenClosed)
            let systemItem = NSMenuItem(title: line.text, action: nil, keyEquivalent: "")
            systemItem.isEnabled = false
            menu.addItem(systemItem)
            menu.addItem(item(title: "Stop Session", action: #selector(AppDelegate.menuStop), target: app))
        } else {
            let start = NSMenuItem(title: "Start Session", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for minutes in durationsMinutes {
                let label = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes > 60 ? "s" : "")"
                let entry = item(title: label, action: #selector(AppDelegate.menuStartPreset(_:)), target: app)
                entry.tag = minutes
                submenu.addItem(entry)
            }
            submenu.addItem(item(title: "Custom…", action: #selector(AppDelegate.menuStartCustom), target: app))
            start.submenu = submenu
            menu.addItem(start)
        }
        let displayToggle = item(title: "Allow Display to Sleep",
                                 action: #selector(AppDelegate.menuToggleDisplayOff), target: app)
        displayToggle.state = allowDisplayOff ? .on : .off
        menu.addItem(displayToggle)
        let lidToggle = item(title: "Keep Awake When Lid Closed",
                             action: #selector(AppDelegate.menuToggleClosedLid), target: app)
        lidToggle.state = closedLidMode ? .on : .off
        menu.addItem(lidToggle)
        menu.addItem(item(title: "Turn Display Off Now", action: #selector(AppDelegate.menuDisplayOff), target: app))

        // ── Slack / Teams Activity ──────────────────────────────────────
        menu.addItem(.separator())
        menu.addItem(sectionHeader("Slack / Teams Activity"))
        let activityToggle = item(title: "Simulate Activity (Keep Active)",
                                  action: #selector(AppDelegate.menuToggleSimulateActivity), target: app)
        activityToggle.state = simulateActivity ? .on : .off
        menu.addItem(activityToggle)
        menu.addItem(activityMethodMenuItem(for: app))
        menu.addItem(activeHoursMenuItem(for: app))
        menu.addItem(item(title: "Test Activity (blip now)",
                          action: #selector(AppDelegate.menuTestActivity), target: app))

        // ── Sleep Timer ─────────────────────────────────────────────────
        menu.addItem(.separator())
        menu.addItem(sectionHeader("Sleep Timer"))
        if app.sleepTimerEndsAt != nil {
            menu.addItem(item(title: "Cancel Sleep Timer",
                              action: #selector(AppDelegate.menuCancelSleepTimer), target: app))
        } else {
            let sleepItem = NSMenuItem(title: "Sleep the Mac after…", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for minutes in durationsMinutes {
                let label = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes > 60 ? "s" : "")"
                let entry = item(title: label, action: #selector(AppDelegate.menuStartSleepPreset(_:)), target: app)
                entry.tag = minutes
                sub.addItem(entry)
            }
            sub.addItem(item(title: "Custom…", action: #selector(AppDelegate.menuStartSleepCustom), target: app))
            sleepItem.submenu = sub
            menu.addItem(sleepItem)
        }

        menu.addItem(.separator())
        menu.addItem(item(title: "Quit WakeGuard", action: #selector(AppDelegate.menuQuit), target: app))
        return menu
    }

    private static func item(title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = target
        return menuItem
    }

    /// A non-clickable section header — native on macOS 14+, disabled label on 13.
    private static func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        return header
    }

    /// "Active Hours ▸" submenu — the daily local-time window in which activity
    /// simulation may run; outside it the app stops simulating within a minute.
    private static func activeHoursMenuItem(for app: AppDelegate) -> NSMenuItem {
        let hours = app.activeHours
        let parent = NSMenuItem(title: "Active Hours: \(hours.displayLabel)",
                                action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let toggle = item(title: "Limit to active hours",
                          action: #selector(AppDelegate.menuToggleActiveHours), target: app)
        toggle.state = hours.isEnabled ? .on : .off
        submenu.addItem(toggle)
        submenu.addItem(.separator())

        func hourSubmenu(title: String, selected: Int, action: Selector) -> NSMenuItem {
            let parent = NSMenuItem(title: "\(title): \(String(format: "%02d:00", selected))",
                                    action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for hour in 0...23 {
                let entry = item(title: String(format: "%02d:00", hour), action: action, target: app)
                entry.tag = hour
                entry.state = (hour == selected) ? .on : .off
                sub.addItem(entry)
            }
            parent.submenu = sub
            parent.isEnabled = hours.isEnabled
            return parent
        }

        submenu.addItem(hourSubmenu(title: "Start", selected: hours.startHour,
                                    action: #selector(AppDelegate.menuSetActiveHoursStart(_:))))
        submenu.addItem(hourSubmenu(title: "End", selected: hours.endHour,
                                    action: #selector(AppDelegate.menuSetActiveHoursEnd(_:))))

        let note = NSMenuItem(title: "Local time; stops simulation outside the window",
                              action: nil, keyEquivalent: "")
        note.isEnabled = false
        submenu.addItem(.separator())
        submenu.addItem(note)

        parent.submenu = submenu
        return parent
    }

    /// "Activity Method ▸" submenu — choose how presence is kept active
    /// (volume / mouse / F16–F19), with a checkmark on the current choice.
    private static func activityMethodMenuItem(for app: AppDelegate) -> NSMenuItem {
        let current = PresenceMethods.method(withID: activityMethodID) ?? PresenceMethods.default
        let parent = NSMenuItem(title: "Activity Method: \(current.displayName)",
                                action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for method in PresenceMethods.all {
            let entry = item(title: method.displayName,
                             action: #selector(AppDelegate.menuSelectActivityMethod(_:)), target: app)
            entry.representedObject = method.id
            entry.state = (method.id == activityMethodID) ? .on : .off
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }
}

extension AppDelegate {
    @objc func menuStartPreset(_ sender: NSMenuItem) {
        startSession(minutes: sender.tag,
                     displayPolicy: MenuBuilder.allowDisplayOff ? .allowOff : .keepOn,
                     lidPolicy: MenuBuilder.closedLidMode ? .stayAwakeWhenClosed : .normalSleep)
    }

    @objc func menuStartCustom() {
        let alert = NSAlert()
        alert.messageText = "Keep awake for how many minutes?"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "e.g. 90"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Int(field.stringValue), minutes > 0 else { return }
        startSession(minutes: minutes,
                     displayPolicy: MenuBuilder.allowDisplayOff ? .allowOff : .keepOn,
                     lidPolicy: MenuBuilder.closedLidMode ? .stayAwakeWhenClosed : .normalSleep)
    }

    @objc func menuStop() { stopSession() }
    @objc func menuDisplayOff() { sleepDisplayNow() }

    @objc func menuToggleDisplayOff() {
        MenuBuilder.allowDisplayOff.toggle()
        rebuildMenu()
    }

    @objc func menuToggleClosedLid() {
        MenuBuilder.closedLidMode.toggle()
        rebuildMenu()
    }

    @objc func menuToggleSimulateActivity() {
        if MenuBuilder.simulateActivity {
            stopActivitySimulation()
            Notify.send(title: "WakeGuard", body: "Activity simulation off.")
        } else {
            startActivitySimulation()
        }
    }

    @objc func menuTestActivity() { testActivityBlip() }

    @objc func menuSelectActivityMethod(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        selectActivityMethod(id: id)
    }

    @objc func menuToggleActiveHours() {
        setActiveHoursEnabled(!activeHours.isEnabled)
    }

    @objc func menuSetActiveHoursStart(_ sender: NSMenuItem) {
        setActiveHoursStart(sender.tag)
    }

    @objc func menuSetActiveHoursEnd(_ sender: NSMenuItem) {
        setActiveHoursEnd(sender.tag)
    }

    @objc func menuStartSleepPreset(_ sender: NSMenuItem) {
        startSleepTimer(duration: TimeInterval(sender.tag * 60))
    }

    @objc func menuStartSleepCustom() {
        let alert = NSAlert()
        alert.messageText = "Sleep the Mac after how many minutes?"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "e.g. 45"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Int(field.stringValue), minutes > 0 else { return }
        startSleepTimer(duration: TimeInterval(minutes * 60))
    }

    @objc func menuCancelSleepTimer() { cancelSleepTimer() }

    @objc func menuQuit() {
        NSApp.terminate(nil)   // triggers applicationWillTerminate -> controller.stop
    }
}
