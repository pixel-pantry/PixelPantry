import Foundation

/// API endpoint definitions
enum Endpoints {
    /// Check for updates endpoint
    /// - Parameters:
    ///   - bundleId: App's bundle identifier
    /// - Returns: Path string
    static func checkForUpdates(bundleId: String) -> String {
        "/v1/apps/\(bundleId)/updates/check"
    }

    /// Download update endpoint
    /// - Parameters:
    ///   - bundleId: App's bundle identifier
    ///   - version: Version to download
    /// - Returns: Path string
    static func downloadUpdate(bundleId: String, version: String) -> String {
        "/v1/apps/\(bundleId)/updates/download/\(version)"
    }
}
