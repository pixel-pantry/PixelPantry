import Foundation

/// Error response from API
private struct APIErrorResponse: Decodable {
    let error: String
    let message: String
}

/// HTTP client for PixelPantry API
actor APIClient {
    private let configuration: Configuration
    private let signer: RequestSigner
    private let session: URLSession

    init(configuration: Configuration) {
        self.configuration = configuration
        self.signer = RequestSigner(appSecret: configuration.appSecret)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Check for Updates

    /// Check for available updates
    /// - Parameters:
    ///   - currentVersion: The currently running version
    ///   - macOSVersion: The user's macOS version (optional)
    /// - Returns: Update check response
    func checkForUpdates(currentVersion: String, macOSVersion: String?) async throws -> UpdateCheckResponse {
        let path = Endpoints.checkForUpdates(bundleId: configuration.bundleId)

        var queryParams: [String: String] = ["currentVersion": currentVersion]
        if let macOS = macOSVersion {
            queryParams["macOSVersion"] = macOS
        }

        let response: UpdateCheckResponse = try await performRequest(
            method: "GET",
            path: path,
            queryParams: queryParams
        )

        return response
    }

    // MARK: - Get Download URL

    /// Get a signed download URL for a specific version
    /// - Parameters:
    ///   - version: Version to download
    /// - Returns: Download response with signed URL
    func getDownloadURL(version: String) async throws -> DownloadResponse {
        let path = Endpoints.downloadUpdate(bundleId: configuration.bundleId, version: version)

        let response: DownloadResponse = try await performRequest(
            method: "GET",
            path: path,
            queryParams: [:]
        )

        return response
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(
        method: String,
        path: String,
        queryParams: [String: String]
    ) async throws -> T {
        // Build query string (sorted for consistent signing)
        let queryString = RequestSigner.buildQueryString(from: queryParams)

        // Create timestamp
        let timestamp = Int(Date().timeIntervalSince1970)

        // Sign the request
        let signature = signer.sign(
            method: method,
            path: path,
            queryString: queryString,
            timestamp: timestamp
        )

        // Build URL
        var urlComponents = URLComponents()
        urlComponents.scheme = configuration.serverURL.scheme
        urlComponents.host = configuration.serverURL.host
        urlComponents.port = configuration.serverURL.port
        urlComponents.path = path

        if !queryParams.isEmpty {
            urlComponents.queryItems = queryParams.keys.sorted().map { key in
                URLQueryItem(name: key, value: queryParams[key])
            }
        }

        guard let url = urlComponents.url else {
            throw PPError.networkError(message: "Failed to construct URL")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add auth headers
        request.setValue(configuration.appKey, forHTTPHeaderField: "X-PixelPantry-AppKey")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-PixelPantry-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-PixelPantry-Signature")

        // Perform request
        let (data, response) = try await session.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PPError.invalidResponse(statusCode: nil, message: "Invalid response type")
        }

        // Handle errors
        if httpResponse.statusCode >= 400 {
            return try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }

        // Decode success response
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PPError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: "Failed to decode response: \(error.localizedDescription)"
            )
        }
    }

    private func handleErrorResponse<T>(data: Data, statusCode: Int) throws -> T {
        // Try to decode error response
        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            throw PPError.fromServerError(code: errorResponse.error, message: errorResponse.message)
        }

        // Generic error
        throw PPError.invalidResponse(
            statusCode: statusCode,
            message: "Server returned error"
        )
    }
}

// MARK: - Response Types

/// Response from the update check endpoint
struct UpdateCheckResponse: Decodable {
    let updateAvailable: Bool
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String?
    let minimumMacOS: String?
    let fileSize: Int64?
    let sha256: String?
    let downloadUrl: String?

    /// Reason for no update (e.g., "incompatible_macos")
    let reason: String?
    let requiredMacOS: String?
    let userMacOS: String?

    /// Convert to Update model if update is available
    func toUpdate() -> Update? {
        guard updateAvailable, let downloadUrl = downloadUrl else {
            return nil
        }

        return Update(
            version: latestVersion,
            releaseNotes: releaseNotes ?? "",
            minimumMacOS: minimumMacOS,
            fileSize: fileSize,
            sha256: sha256,
            downloadPath: downloadUrl
        )
    }
}

/// Response from the download endpoint
struct DownloadResponse: Decodable {
    let downloadUrl: String
    let expiresAt: String
    let sha256: String?
    let fileSize: Int64?
    let fileName: String?

    var expirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: expiresAt)
    }
}
