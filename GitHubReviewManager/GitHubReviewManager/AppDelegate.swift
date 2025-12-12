import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var trayMenuManager: TrayMenuManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }.count > 1

        if isRunning {
            NSApp.terminate(nil)
            return
        }

        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Set notification delegate BEFORE requesting permissions
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        Task {
            await NotificationService.shared.requestPermissions()
        }

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

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        trayMenuManager?.showPopover()
        completionHandler()
    }
}

