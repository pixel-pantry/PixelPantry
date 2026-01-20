import Foundation

/// Downloads update files with progress tracking
actor Downloader {
    private var downloadTask: URLSessionDownloadTask?

    /// Download a file with progress tracking and SHA256 verification
    /// - Parameters:
    ///   - url: URL to download from
    ///   - expectedSHA256: Expected SHA256 hash (optional, but recommended)
    ///   - fileName: Optional filename to use (if not provided, extracted from URL)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: Local URL of the downloaded file
    func download(
        from url: URL,
        expectedSHA256: String?,
        fileName: String? = nil,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        // Create a temporary directory for this download
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelPantry")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Determine filename - prefer provided name, then try URL, then default
        let resolvedFileName: String
        if let providedName = fileName, !providedName.isEmpty {
            resolvedFileName = providedName
        } else {
            let urlFileName = url.lastPathComponent
            resolvedFileName = urlFileName.isEmpty || urlFileName == "/" ? "download.zip" : urlFileName
        }
        let destinationURL = tempDir.appendingPathComponent(resolvedFileName)

        // Download using delegate for progress
        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        defer {
            session.finishTasksAndInvalidate()
        }

        let (tempURL, response) = try await session.download(from: url)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw PPError.downloadFailed(reason: "Server returned HTTP \(httpResponse.statusCode)")
            }
        }

        // Move to our temp directory
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Verify SHA256 if provided
        if let expectedHash = expectedSHA256, !expectedHash.isEmpty {
            do {
                let isValid = try Verifier.verifySHA256(fileURL: destinationURL, expected: expectedHash)
                if !isValid {
                    // Clean up invalid file
                    try? FileManager.default.removeItem(at: destinationURL)
                    throw PPError.verificationFailed
                }
            } catch let error as PPError {
                throw error
            } catch {
                throw PPError.downloadFailed(reason: "Failed to verify file: \(error.localizedDescription)")
            }
        }

        return destinationURL
    }

    /// Cancel any in-progress download
    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
    }
}

// MARK: - Download Delegate

/// Delegate to track download progress
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let progressHandler: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.progressHandler = progress
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { [progressHandler] in
            progressHandler(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // This is required but we handle the file in the async download method
    }
}
