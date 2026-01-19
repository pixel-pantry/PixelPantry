import Foundation
import SwiftUI

/// View model for the update UI
@MainActor
public final class UpdateViewModel: ObservableObject {
    /// The available update (if any)
    @Published public var update: Update?

    /// Whether we're currently checking for updates
    @Published public var isChecking: Bool = false

    /// Whether we're currently downloading
    @Published public var isDownloading: Bool = false

    /// Whether we're currently installing
    @Published public var isInstalling: Bool = false

    /// Download progress (0.0 to 1.0)
    @Published public var downloadProgress: Double = 0

    /// Error message (if any)
    @Published public var errorMessage: String?

    /// Current state of the update process
    public enum State {
        case idle
        case checking
        case updateAvailable
        case upToDate
        case downloading
        case installing
        case error(String)
    }

    @Published public var state: State = .idle

    public init() {}

    /// Check for updates
    public func checkForUpdates() async {
        state = .checking
        isChecking = true
        errorMessage = nil

        let result = await PixelPantry.checkForUpdates()

        isChecking = false

        switch result {
        case .available(let foundUpdate):
            update = foundUpdate
            state = .updateAvailable

        case .upToDate:
            update = nil
            state = .upToDate

        case .error(let error):
            errorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    /// Download and install the current update
    public func downloadAndInstall() async {
        guard let update = update else { return }

        state = .downloading
        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        let downloadResult = await PixelPantry.downloadUpdate(update) { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress
            }
        }

        isDownloading = false

        switch downloadResult {
        case .success(let localURL):
            state = .installing
            isInstalling = true

            let installResult = await PixelPantry.installUpdate(from: localURL)

            isInstalling = false

            switch installResult {
            case .success:
                // App will relaunch, this won't be reached
                break

            case .failure(let error):
                errorMessage = error.localizedDescription
                state = .error(error.localizedDescription)
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    /// Reset to check again
    public func reset() {
        update = nil
        isChecking = false
        isDownloading = false
        isInstalling = false
        downloadProgress = 0
        errorMessage = nil
        state = .idle
    }
}
