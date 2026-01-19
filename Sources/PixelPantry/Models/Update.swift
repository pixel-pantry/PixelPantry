import Foundation

/// Represents an available update from PixelPantry
public struct Update: Sendable, Equatable {
    /// The version string (semver, e.g., "1.2.0")
    public let version: String

    /// Release notes (may contain markdown)
    public let releaseNotes: String

    /// Minimum macOS version required
    public let minimumMacOS: String?

    /// File size in bytes
    public let fileSize: Int64?

    /// SHA256 hash of the download file for verification
    public let sha256: String?

    /// Relative path to download the update
    public let downloadPath: String

    /// Human-readable file size (e.g., "15.2 MB")
    public var fileSizeFormatted: String {
        guard let size = fileSize else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Initialize an Update
    public init(
        version: String,
        releaseNotes: String,
        minimumMacOS: String?,
        fileSize: Int64?,
        sha256: String?,
        downloadPath: String
    ) {
        self.version = version
        self.releaseNotes = releaseNotes
        self.minimumMacOS = minimumMacOS
        self.fileSize = fileSize
        self.sha256 = sha256
        self.downloadPath = downloadPath
    }
}

/// Result of checking for updates
public enum UpdateCheckResult: Sendable {
    /// An update is available
    case available(Update)

    /// Currently running the latest version
    case upToDate

    /// An error occurred while checking
    case error(PPError)

    /// Returns the update if available, nil otherwise
    public var update: Update? {
        if case .available(let update) = self {
            return update
        }
        return nil
    }

    /// Returns true if an update is available
    public var isUpdateAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    /// Returns the error if one occurred, nil otherwise
    public var error: PPError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}
