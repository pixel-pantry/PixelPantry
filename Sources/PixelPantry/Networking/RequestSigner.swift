import Foundation
import CryptoKit

/// Signs API requests using HMAC-SHA256
struct RequestSigner: Sendable {
    let appSecret: String

    /// Create a new request signer
    /// - Parameter appSecret: The app's secret key (starts with "sk_")
    init(appSecret: String) {
        self.appSecret = appSecret
    }

    /// Sign a request
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: Request path (e.g., "/v1/apps/com.example/updates/check")
    ///   - queryString: Sorted query string without leading "?" (e.g., "currentVersion=1.0.0&macOSVersion=14.2")
    ///   - timestamp: Unix timestamp in seconds
    /// - Returns: Hex-encoded HMAC-SHA256 signature
    func sign(method: String, path: String, queryString: String, timestamp: Int) -> String {
        // Format: "{timestamp}.{method}.{path}.{queryString}"
        let stringToSign = "\(timestamp).\(method.uppercased()).\(path).\(queryString)"

        let key = SymmetricKey(data: Data(appSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: key
        )

        // Convert to hex string
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    /// Build a sorted query string from parameters
    /// - Parameter params: Dictionary of query parameters
    /// - Returns: URL-encoded query string with sorted keys
    static func buildQueryString(from params: [String: String]) -> String {
        guard !params.isEmpty else { return "" }

        return params.keys.sorted().compactMap { key in
            guard let value = params[key],
                  let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else { return nil }

            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }
}

/// Signed request headers
struct SignedRequestHeaders: Sendable {
    let appKey: String
    let timestamp: String
    let signature: String

    /// Apply headers to a URLRequest
    func apply(to request: inout URLRequest) {
        request.setValue(appKey, forHTTPHeaderField: "X-PixelPantry-AppKey")
        request.setValue(timestamp, forHTTPHeaderField: "X-PixelPantry-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-PixelPantry-Signature")
    }

    /// Get headers as a dictionary
    var dictionary: [String: String] {
        [
            "X-PixelPantry-AppKey": appKey,
            "X-PixelPantry-Timestamp": timestamp,
            "X-PixelPantry-Signature": signature
        ]
    }
}
