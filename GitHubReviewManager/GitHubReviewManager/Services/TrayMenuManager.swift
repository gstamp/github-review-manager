import AppKit
import SwiftUI

class TrayMenuManager {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func createTrayIcon() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Load icon from bundle
        // Try multiple possible paths
        var iconImage: NSImage?

        // Try assets folder in bundle
        if let iconPath = Bundle.main.path(forResource: "icon", ofType: "png", inDirectory: "assets") {
            iconImage = NSImage(contentsOfFile: iconPath)
        }

        // Try root of bundle
        if iconImage == nil, let iconPath = Bundle.main.path(forResource: "icon", ofType: "png") {
            iconImage = NSImage(contentsOfFile: iconPath)
        }

        // Try from main bundle resources
        if iconImage == nil, let imagePath = Bundle.main.path(forResource: "icon", ofType: "png", inDirectory: nil) {
            iconImage = NSImage(contentsOfFile: imagePath)
        }

        if let icon = iconImage {
            icon.isTemplate = true // Allow system styling
            statusItem.button?.image = icon
        } else {
            // Fallback: create a simple icon programmatically
            let iconImage = NSImage(size: NSSize(width: 16, height: 16))
            iconImage.lockFocus()
            NSColor.purple.setFill()
            NSRect(origin: .zero, size: iconImage.size).fill()
            iconImage.unlockFocus()
            iconImage.isTemplate = true
            statusItem.button?.image = iconImage
        }

        statusItem.button?.toolTip = "GitHub Review Manager"

        // Ensure button image is set
        if statusItem.button?.image == nil {
            print("Warning: Status item button image is nil after setup")
        }

        // Handle click to toggle popover
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        self.statusItem = statusItem
        return statusItem
    }

    func createPopover() -> NSPopover {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 800, height: 600)
        popover.behavior = .transient // Don't steal focus
        popover.animates = true

        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)

        popover.contentViewController = hostingController

        self.popover = popover
        return popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Show popover relative to status item button
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Enable mouse tracking and focus the window so hover cursors work immediately
            // Use a small delay to ensure window is shown first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = popover.contentViewController?.view.window {
                    window.acceptsMouseMovedEvents = true
                    // Make the window key so it receives focus and hover events work
                    window.makeKey()
                }
            }

            // Add Esc key handler to close popover
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Esc key
                    popover.performClose(nil)
                    return nil
                }
                return event
            }
        }
    }
}

