import AppKit
import WakeGuardCore

enum MenuBuilder {
    static let durationsMinutes = [15, 30, 60, 120, 240, 480]

    // Mode toggles persist across menu rebuilds.
    static var allowDisplayOff = false
    static var closedLidMode = false
    static var simulateActivity = false

    // Show the Accessibility-permission hint only the first time activity
    // simulation is enabled in a given launch, so it isn't a per-toggle nag.
    static var didHintActivityPermission = false

    // Currently selected activity key id (loaded from / saved to UserDefaults by
    // AppDelegate). Drives the "Activity Key" submenu checkmark.
    static var activityKeyID = PresenceKeys.default.id

    static func build(for app: AppDelegate) -> NSMenu {
        let menu = NSMenu()

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

        menu.addItem(.separator())
        let displayToggle = item(title: "Allow Display to Sleep",
                                 action: #selector(AppDelegate.menuToggleDisplayOff), target: app)
        displayToggle.state = allowDisplayOff ? .on : .off
        menu.addItem(displayToggle)

        let lidToggle = item(title: "Keep Awake When Lid Closed",
                             action: #selector(AppDelegate.menuToggleClosedLid), target: app)
        lidToggle.state = closedLidMode ? .on : .off
        menu.addItem(lidToggle)

        let activityToggle = item(title: "Simulate Activity (Keep Slack/Teams Active)",
                                  action: #selector(AppDelegate.menuToggleSimulateActivity), target: app)
        activityToggle.state = simulateActivity ? .on : .off
        menu.addItem(activityToggle)

        menu.addItem(activityKeyMenuItem(for: app))

        menu.addItem(item(title: "Turn Display Off Now", action: #selector(AppDelegate.menuDisplayOff), target: app))
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit WakeGuard", action: #selector(AppDelegate.menuQuit), target: app))
        return menu
    }

    private static func item(title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = target
        return menuItem
    }

    /// "Activity Key ▸" submenu — pick the key that's tapped to keep presence
    /// active. Grouped into recommended function keys and modifier keys, with a
    /// checkmark on the current choice. Selection is persisted by AppDelegate.
    private static func activityKeyMenuItem(for app: AppDelegate) -> NSMenuItem {
        let currentName = PresenceKeys.key(withID: activityKeyID)?.displayName ?? "—"
        let parent = NSMenuItem(title: "Activity Key: \(currentName)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        func addGroup(_ header: String, _ keys: [PresenceKey]) {
            let head = NSMenuItem(title: header, action: nil, keyEquivalent: "")
            head.isEnabled = false
            submenu.addItem(head)
            for key in keys {
                let entry = item(title: key.displayName,
                                 action: #selector(AppDelegate.menuSelectActivityKey(_:)), target: app)
                entry.representedObject = key.id
                entry.state = (key.id == activityKeyID) ? .on : .off
                submenu.addItem(entry)
            }
        }

        addGroup("Function keys (recommended)", PresenceKeys.functionKeys)
        submenu.addItem(.separator())
        addGroup("Modifier keys", PresenceKeys.modifierKeys)

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
        MenuBuilder.simulateActivity.toggle()
        if MenuBuilder.simulateActivity {
            activitySimulator.start()
            // Synthetic events are silently filtered if WakeGuard lacks
            // Accessibility/Input-Monitoring permission, so surface that once
            // up front rather than leaving the user wondering why presence lapses.
            if MenuBuilder.didHintActivityPermission {
                Notify.send(title: "WakeGuard",
                            body: "Activity simulation on — presence stays active (Slack/Teams).")
            } else {
                MenuBuilder.didHintActivityPermission = true
                Notify.send(title: "WakeGuard",
                            body: "Activity simulation on. If Slack/Teams still go idle, grant WakeGuard Accessibility access in System Settings → Privacy & Security.")
            }
        } else {
            activitySimulator.stop()
            Notify.send(title: "WakeGuard", body: "Activity simulation off.")
        }
        refreshStatusIcon()
        rebuildMenu()
    }

    @objc func menuSelectActivityKey(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        selectActivityKey(id: id)
    }

    @objc func menuQuit() {
        NSApp.terminate(nil)   // triggers applicationWillTerminate -> controller.stop
    }
}
