import AppKit
import WakeGuardCore

enum MenuBuilder {
    static let durationsMinutes = [15, 30, 60, 120, 240, 480]

    // Mode toggles persist across menu rebuilds.
    static var allowDisplayOff = false
    static var closedLidMode = false

    static func build(for app: AppDelegate) -> NSMenu {
        let menu = NSMenu()

        if let session = app.controller.activeSession {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let status = NSMenuItem(title: "Awake until \(formatter.string(from: session.endsAt))",
                                    action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
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

    @objc func menuQuit() {
        NSApp.terminate(nil)   // triggers applicationWillTerminate -> controller.stop
    }
}
