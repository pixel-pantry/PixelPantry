import Foundation

/// Errors that can occur when using the PixelPantry SDK
public enum PPError: LocalizedError, Sendable {
    /// SDK has not been configured. Call `PixelPantry.configure()` first.
    case notConfigured

    /// Network request failed
    case networkError(message: String)

    /// Server returned an invalid or unexpected response
    case invalidResponse(statusCode: Int?, message: String)

    /// Request signing failed
    case signatureError(message: String)

    /// Download failed
    case downloadFailed(reason: String)

    /// Downloaded file failed SHA256 verification
    case verificationFailed

    /// Installation failed
    case installationFailed(reason: String)

    /// App not found on PixelPantry
    case appNotFound

    /// App has been suspended from the platform
    case appSuspended

    /// Version not found or not available
    case versionNotFound

    /// The requested version is not yet approved
    case versionNotApproved

    /// Server returned an error
    case serverError(code: String, message: String)

    /// Unknown error
    case unknown(message: String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "PixelPantry SDK not configured. Call PixelPantry.configure() first."

        case .networkError(let message):
            return "Network error: \(message)"

        case .invalidResponse(let statusCode, let message):
            if let code = statusCode {
                return "Invalid response (HTTP \(code)): \(message)"
            }
            return "Invalid response: \(message)"

        case .signatureError(let message):
            return "Request signing failed: \(message)"

        case .downloadFailed(let reason):
            return "Download failed: \(reason)"

        case .verificationFailed:
            return "Downloaded file verification failed. The file may be corrupted."

        case .installationFailed(let reason):
            return "Installation failed: \(reason)"

        case .appNotFound:
            return "App not found on PixelPantry"

        case .appSuspended:
            return "This app has been suspended from PixelPantry"

        case .versionNotFound:
            return "Requested version not found"

        case .versionNotApproved:
            return "Requested version is not yet approved"

        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"

        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }

    /// Create a PPError from a server error response
    static func fromServerError(code: String, message: String) -> PPError {
        switch code {
        case "app_not_found":
            return .appNotFound
        case "app_suspended":
            return .appSuspended
        case "version_not_found":
            return .versionNotFound
        case "version_not_approved":
            return .versionNotApproved
        case "invalid_signature", "timestamp_expired", "missing_app_key":
            return .signatureError(message: message)
        default:
            return .serverError(code: code, message: message)
        }
    }
}
