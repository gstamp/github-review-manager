import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var trayMenuManager: TrayMenuManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Initialize tray menu
        trayMenuManager = TrayMenuManager()
        statusItem = trayMenuManager?.createTrayIcon()
        popover = trayMenuManager?.createPopover()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't reopen window when clicking dock icon (menu bar only app)
        return false
    }
}

