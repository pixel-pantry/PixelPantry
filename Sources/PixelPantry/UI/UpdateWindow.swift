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

    /// Check for updates and show an alert if one is available
    ///
    /// This method checks for updates and presents a native macOS alert dialog
    /// asking if the user wants to install the update. If they click "Install Now",
    /// the update window is shown. If they click "Later", the alert is dismissed.
    ///
    /// - Returns: `true` if an update was found, `false` otherwise
    @MainActor
    @discardableResult
    static func checkAndPromptForUpdate() async -> Bool {
        let result = await checkForUpdates()

        guard case .available(let update) = result else {
            return false
        }

        return promptForUpdate(update)
    }

    /// Show an alert prompting the user to install an update
    ///
    /// - Parameter update: The update to prompt for
    /// - Returns: `true` if the user chose to install, `false` if they chose later
    @MainActor
    @discardableResult
    static func promptForUpdate(_ update: Update) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Update Available"

        // Build informative text
        var infoText = "Version \(update.version) is available."
        infoText += " You are currently running version \(currentVersion)."

        if !update.releaseNotes.isEmpty {
            infoText += "\n\n\(update.releaseNotes)"
        }

        infoText += "\n\nWould you like to install this update now?"

        alert.informativeText = infoText
        alert.alertStyle = .informational

        // Add app icon if available
        if let appIcon = NSApp.applicationIconImage {
            alert.icon = appIcon
        }

        alert.addButton(withTitle: "Install Now")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // User clicked "Install Now"
            showUpdateWindow(for: update)
            return true
        }

        return false
    }

    /// Check for updates silently and prompt only if an update is available
    ///
    /// This is the recommended method for automatic update checks on app launch.
    /// It checks for updates in the background and only shows UI if an update is found.
    ///
    /// - Parameter showAlertFirst: If `true`, shows an alert before the update window.
    ///                             If `false`, shows the update window directly.
    @MainActor
    static func checkForUpdatesOnLaunch(showAlertFirst: Bool = true) async {
        let result = await checkForUpdates()

        guard case .available(let update) = result else {
            return
        }

        if showAlertFirst {
            _ = promptForUpdate(update)
        } else {
            showUpdateWindow(for: update)
        }
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
