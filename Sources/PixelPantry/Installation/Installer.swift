import Foundation
import AppKit

/// Handles app installation from downloaded files
actor Installer {
    /// Install an update from a downloaded file
    /// - Parameter downloadedFile: Path to the .dmg or .zip file
    func install(from downloadedFile: URL) async throws {
        let ext = downloadedFile.pathExtension.lowercased()

        switch ext {
        case "dmg":
            try await installFromDMG(downloadedFile)
        case "zip":
            try await installFromZIP(downloadedFile)
        default:
            throw PPError.installationFailed(reason: "Unsupported file type: .\(ext)")
        }
    }

    // MARK: - DMG Installation

    private func installFromDMG(_ dmgURL: URL) async throws {
        // Create unique mount point
        let mountPoint = "/Volumes/PixelPantryUpdate-\(UUID().uuidString.prefix(8))"

        // Mount the DMG
        try await mountDMG(at: dmgURL, mountPoint: mountPoint)

        defer {
            // Always try to unmount
            Task {
                await unmountDMG(mountPoint: mountPoint)
            }
        }

        // Find the .app in the mounted volume
        let mountURL = URL(fileURLWithPath: mountPoint)
        guard let appURL = try findAppBundle(in: mountURL) else {
            throw PPError.installationFailed(reason: "No .app bundle found in DMG")
        }

        // Install the app
        try await installApp(from: appURL)
    }

    private func mountDMG(at url: URL, mountPoint: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = [
            "attach",
            url.path,
            "-mountpoint", mountPoint,
            "-nobrowse",
            "-noverify",
            "-noautoopen"
        ]

        let errorPipe = Pipe()
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            throw PPError.installationFailed(reason: "Failed to mount DMG: \(error.localizedDescription)")
        }

        guard task.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PPError.installationFailed(reason: "Failed to mount DMG: \(errorMessage)")
        }
    }

    private func unmountDMG(mountPoint: String) async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", mountPoint, "-force"]

        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - ZIP Installation

    private func installFromZIP(_ zipURL: URL) async throws {
        // Create extraction directory
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelPantryExtract-\(UUID().uuidString.prefix(8))")

        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: extractDir)
        }

        // Unzip
        try await unzip(zipURL, to: extractDir)

        // Find the .app
        guard let appURL = try findAppBundle(in: extractDir) else {
            throw PPError.installationFailed(reason: "No .app bundle found in ZIP")
        }

        // Install the app
        try await installApp(from: appURL)
    }

    private func unzip(_ zipURL: URL, to destination: URL) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-xk", zipURL.path, destination.path]

        let errorPipe = Pipe()
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            throw PPError.installationFailed(reason: "Failed to unzip: \(error.localizedDescription)")
        }

        guard task.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PPError.installationFailed(reason: "Failed to unzip: \(errorMessage)")
        }
    }

    // MARK: - App Installation

    private func findAppBundle(in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        // Look for .app bundle
        for url in contents {
            if url.pathExtension == "app" {
                return url
            }
        }

        // Search one level deeper (some DMGs have a folder)
        for url in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let subContents = try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil
                )
                if let appURL = subContents?.first(where: { $0.pathExtension == "app" }) {
                    return appURL
                }
            }
        }

        return nil
    }

    private func installApp(from sourceURL: URL) async throws {
        // Determine current app location
        let currentAppURL = Bundle.main.bundleURL

        // Determine destination (usually /Applications or same directory as current)
        let destinationURL: URL

        if currentAppURL.path.hasPrefix("/Applications") {
            // App is in /Applications
            destinationURL = URL(fileURLWithPath: "/Applications")
                .appendingPathComponent(sourceURL.lastPathComponent)
        } else {
            // App is elsewhere - replace in same location
            destinationURL = currentAppURL.deletingLastPathComponent()
                .appendingPathComponent(sourceURL.lastPathComponent)
        }

        // Try direct installation first, fall back to AppleScript if permission denied
        do {
            try await installDirectly(from: sourceURL, to: destinationURL)
        } catch {
            // If direct installation fails (likely permission issue), try with admin privileges
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("permission") || errorMessage.contains("access") || errorMessage.contains("denied") {
                try await installWithAppleScript(from: sourceURL, to: destinationURL)
            } else {
                throw error
            }
        }

        // Relaunch the new app
        await relaunchApp(at: destinationURL)
    }

    private func installDirectly(from sourceURL: URL, to destinationURL: URL) async throws {
        // Remove old app (if replacing)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // Move to trash instead of delete for safety
            do {
                try FileManager.default.trashItem(at: destinationURL, resultingItemURL: nil)
            } catch {
                // If trash fails, try direct removal - but throw if that also fails
                do {
                    try FileManager.default.removeItem(at: destinationURL)
                } catch {
                    throw PPError.installationFailed(reason: error.localizedDescription)
                }
            }
        }

        // Copy new app
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw PPError.installationFailed(reason: "Failed to copy app: \(error.localizedDescription)")
        }
    }

    private func installWithAppleScript(from sourceURL: URL, to destinationURL: URL) async throws {
        // Escape paths for shell - escape single quotes by ending the quote, adding escaped quote, starting new quote
        func shellEscape(_ path: String) -> String {
            return path.replacingOccurrences(of: "'", with: "'\\''")
        }

        let sourcePath = shellEscape(sourceURL.path)
        let destPath = shellEscape(destinationURL.path)
        let destDir = shellEscape(destinationURL.deletingLastPathComponent().path)

        // Build AppleScript to remove old and copy new with admin privileges
        let script = """
        do shell script "rm -rf '\\(destPath)' && cp -R '\\(sourcePath)' '\\(destDir)/'" with administrator privileges
        """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)

        // Run on main thread since NSAppleScript needs it for the auth dialog
        let success = await MainActor.run { () -> Bool in
            let result = appleScript?.executeAndReturnError(&error)
            return result != nil
        }

        if !success {
            let errorNumber = error?[NSAppleScript.errorNumber] as? Int ?? 0
            let errorMessage = error?[NSAppleScript.errorMessage] as? String ?? "Unknown error"

            // Error -128 means user cancelled
            if errorNumber == -128 {
                throw PPError.installationFailed(reason: "Installation cancelled by user")
            }

            throw PPError.installationFailed(reason: "Installation failed: \(errorMessage)")
        }
    }

    @MainActor
    private func relaunchApp(at appURL: URL) async {
        // Small delay to ensure file operations complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Launch the new app
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        do {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)

            // Give the new instance time to launch
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Terminate current instance
            NSApplication.shared.terminate(nil)
        } catch {
            // If NSWorkspace fails, try Process
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", appURL.path]

            try? task.run()

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            NSApplication.shared.terminate(nil)
        }
    }
}
