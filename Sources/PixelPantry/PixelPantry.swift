import Foundation

/// Main interface for the PixelPantry SDK
///
/// Use this class to configure the SDK and check for updates.
///
/// ## Example
/// ```swift
/// // Configure on app launch
/// PixelPantry.configure(
///     bundleId: "com.example.myapp",
///     appKey: "pk_abc123",
///     appSecret: "sk_xyz789"
/// )
///
/// // Check for updates
/// let result = await PixelPantry.checkForUpdates()
/// switch result {
/// case .available(let update):
///     print("Update available: \(update.version)")
/// case .upToDate:
///     print("Running latest version")
/// case .error(let error):
///     print("Error: \(error)")
/// }
/// ```
public final class PixelPantry: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = PixelPantry()

    /// Internal API client (created lazily after configuration)
    private var apiClient: APIClient?

    /// Private initializer for singleton
    private init() {}

    // MARK: - Configuration

    /// Configure the PixelPantry SDK
    ///
    /// Call this method once during app initialization (e.g., in your App's init or AppDelegate).
    ///
    /// - Parameters:
    ///   - bundleId: Your app's bundle identifier registered with PixelPantry
    ///   - appKey: Public API key (starts with "pk_")
    ///   - appSecret: Private secret for signing requests (starts with "sk_")
    ///   - serverURL: Custom server URL (defaults to production)
    public static func configure(
        bundleId: String,
        appKey: String,
        appSecret: String,
        serverURL: URL = Configuration.defaultServerURL
    ) {
        let config = Configuration(
            bundleId: bundleId,
            appKey: appKey,
            appSecret: appSecret,
            serverURL: serverURL
        )

        Task {
            await ConfigurationStorage.shared.set(config)
        }

        shared.apiClient = APIClient(configuration: config)
    }

    /// Check if the SDK has been configured
    public static var isConfigured: Bool {
        shared.apiClient != nil
    }

    // MARK: - Version Info

    /// Get the current app version from the bundle
    public static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Get the current macOS version
    public static var currentMacOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    // MARK: - Update Checking

    /// Check for available updates
    ///
    /// This method contacts the PixelPantry server to check if a newer version
    /// of your app is available.
    ///
    /// - Returns: `UpdateCheckResult` indicating if an update is available
    public static func checkForUpdates() async -> UpdateCheckResult {
        await shared.checkForUpdatesInternal()
    }

    /// Check for updates with a completion handler (for compatibility)
    ///
    /// - Parameter completion: Called with the result on the main thread
    public static func checkForUpdates(completion: @escaping (UpdateCheckResult) -> Void) {
        Task {
            let result = await checkForUpdates()
            await MainActor.run {
                completion(result)
            }
        }
    }

    private func checkForUpdatesInternal() async -> UpdateCheckResult {
        guard let client = apiClient else {
            return .error(.notConfigured)
        }

        do {
            let response = try await client.checkForUpdates(
                currentVersion: Self.currentVersion,
                macOSVersion: Self.currentMacOSVersion
            )

            if let update = response.toUpdate() {
                return .available(update)
            } else {
                return .upToDate
            }
        } catch let error as PPError {
            return .error(error)
        } catch {
            return .error(.networkError(message: error.localizedDescription))
        }
    }

    // MARK: - Download

    /// Download an update
    ///
    /// Downloads the update file to a temporary location and verifies its integrity.
    ///
    /// - Parameters:
    ///   - update: The update to download
    ///   - progress: Optional progress callback (0.0 to 1.0)
    /// - Returns: Result with the local file URL on success
    public static func downloadUpdate(
        _ update: Update,
        progress: @escaping (Double) -> Void = { _ in }
    ) async -> Result<URL, PPError> {
        await shared.downloadUpdateInternal(update, progress: progress)
    }

    private func downloadUpdateInternal(
        _ update: Update,
        progress: @escaping (Double) -> Void
    ) async -> Result<URL, PPError> {
        guard let client = apiClient else {
            return .failure(.notConfigured)
        }

        do {
            // Get signed download URL
            let downloadResponse = try await client.getDownloadURL(version: update.version)

            guard let downloadURL = URL(string: downloadResponse.downloadUrl) else {
                return .failure(.downloadFailed(reason: "Invalid download URL"))
            }

            // Download the file
            let downloader = Downloader()
            let localURL = try await downloader.download(
                from: downloadURL,
                expectedSHA256: update.sha256 ?? downloadResponse.sha256,
                fileName: downloadResponse.fileName,
                progress: progress
            )

            return .success(localURL)
        } catch let error as PPError {
            return .failure(error)
        } catch {
            return .failure(.downloadFailed(reason: error.localizedDescription))
        }
    }

    // MARK: - Installation

    /// Install an update from a downloaded file
    ///
    /// This method will:
    /// 1. Extract the app from the .dmg or .zip
    /// 2. Copy it to /Applications (replacing the current version)
    /// 3. Relaunch the new version
    ///
    /// - Parameter localURL: Path to the downloaded .dmg or .zip file
    /// - Returns: Result indicating success or failure
    public static func installUpdate(from localURL: URL) async -> Result<Void, PPError> {
        await shared.installUpdateInternal(from: localURL)
    }

    private func installUpdateInternal(from localURL: URL) async -> Result<Void, PPError> {
        do {
            let installer = Installer()
            try await installer.install(from: localURL)
            return .success(())
        } catch let error as PPError {
            return .failure(error)
        } catch {
            return .failure(.installationFailed(reason: error.localizedDescription))
        }
    }

    // MARK: - Combined Download + Install

    /// Download and install an update in one step
    ///
    /// - Parameters:
    ///   - update: The update to download and install
    ///   - progress: Optional progress callback (0.0 to 1.0 for download)
    /// - Returns: Result indicating success or failure
    public static func downloadAndInstall(
        _ update: Update,
        progress: @escaping (Double) -> Void = { _ in }
    ) async -> Result<Void, PPError> {
        // Download
        let downloadResult = await downloadUpdate(update, progress: progress)

        switch downloadResult {
        case .success(let localURL):
            // Install
            return await installUpdate(from: localURL)

        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Automatic Update Checks

public extension PixelPantry {
    /// Time interval for automatic checks
    enum CheckInterval: Sendable {
        case hours(Int)
        case minutes(Int)

        var timeInterval: TimeInterval {
            switch self {
            case .hours(let h): return TimeInterval(h * 60 * 60)
            case .minutes(let m): return TimeInterval(m * 60)
            }
        }
    }

    /// Enable automatic background checks for updates
    ///
    /// When an update is found, the callback is called. Return `true` to show
    /// the built-in update UI, or `false` to handle it yourself.
    ///
    /// - Parameters:
    ///   - interval: How often to check
    ///   - onUpdateFound: Called when an update is found
    static func enableAutomaticChecks(
        interval: CheckInterval,
        onUpdateFound: @escaping @Sendable (Update) -> Bool
    ) {
        shared.startAutomaticChecks(interval: interval, onUpdateFound: onUpdateFound)
    }

    /// Disable automatic update checks
    static func disableAutomaticChecks() {
        shared.stopAutomaticChecks()
    }

    private func startAutomaticChecks(
        interval: CheckInterval,
        onUpdateFound: @escaping @Sendable (Update) -> Bool
    ) {
        // Store the callback and interval
        automaticCheckInterval = interval.timeInterval
        automaticCheckCallback = onUpdateFound

        // Schedule first check after a short delay
        scheduleNextCheck(delay: 60) // 1 minute after app launch
    }

    private func stopAutomaticChecks() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil
        automaticCheckCallback = nil
    }

    private func scheduleNextCheck(delay: TimeInterval) {
        automaticCheckTask?.cancel()

        automaticCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            let result = await PixelPantry.checkForUpdates()

            if case .available(let update) = result {
                if let callback = self?.automaticCheckCallback {
                    let showUI = callback(update)
                    if showUI {
                        await MainActor.run {
                            PixelPantry.showUpdateWindow(for: update)
                        }
                    }
                }
            }

            // Schedule next check
            if let interval = self?.automaticCheckInterval {
                self?.scheduleNextCheck(delay: interval)
            }
        }
    }

    // Storage for automatic checks
    private var automaticCheckInterval: TimeInterval {
        get { _automaticCheckInterval }
        set { _automaticCheckInterval = newValue }
    }

    private var automaticCheckCallback: (@Sendable (Update) -> Bool)? {
        get { _automaticCheckCallback }
        set { _automaticCheckCallback = newValue }
    }

    private var automaticCheckTask: Task<Void, Never>? {
        get { _automaticCheckTask }
        set { _automaticCheckTask = newValue }
    }
}

// Private storage (outside the extension for mutability)
private var _automaticCheckInterval: TimeInterval = 0
private var _automaticCheckCallback: (@Sendable (Update) -> Bool)?
private var _automaticCheckTask: Task<Void, Never>?
