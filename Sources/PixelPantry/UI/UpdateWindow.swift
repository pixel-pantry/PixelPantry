import AppKit
import SwiftUI

/// AppKit window for showing updates
public extension PixelPantry {
    /// Show the update window if an update is available
    ///
    /// This method checks for updates and shows a window if one is available.
    @MainActor
    static func showUpdateWindowIfAvailable() async {
        let result = await checkForUpdates()
        if case .available(let update) = result {
            showUpdateWindow(for: update)
        }
    }

    /// Show the update window for a specific update
    ///
    /// - Parameter update: The update to display
    @MainActor
    static func showUpdateWindow(for update: Update) {
        let controller = UpdateWindowController(update: update)
        controller.showWindow(nil)
    }
}

/// Window controller for the update window
final class UpdateWindowController: NSWindowController {
    init(update: Update) {
        let contentView = PixelPantryUpdateView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Software Update"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        // Set minimum size
        window.minSize = NSSize(width: 400, height: 300)
        window.setContentSize(NSSize(width: 400, height: 350))

        super.init(window: window)

        // Keep a reference so it doesn't get deallocated
        UpdateWindowController.activeController = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Static reference to keep window alive
    private static var activeController: UpdateWindowController?
}
