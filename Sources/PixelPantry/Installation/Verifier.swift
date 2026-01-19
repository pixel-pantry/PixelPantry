import Foundation
import CryptoKit

/// Verifies file integrity using SHA256
struct Verifier {
    /// Verify a file's SHA256 hash
    /// - Parameters:
    ///   - fileURL: Path to the file
    ///   - expectedHash: Expected SHA256 hash (hex string)
    /// - Returns: true if hash matches
    static func verifySHA256(fileURL: URL, expected: String) throws -> Bool {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        return hashString.lowercased() == expected.lowercased()
    }

    /// Calculate SHA256 hash of a file
    /// - Parameter fileURL: Path to the file
    /// - Returns: Hex-encoded SHA256 hash
    static func calculateSHA256(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Calculate SHA256 hash of data
    /// - Parameter data: Data to hash
    /// - Returns: Hex-encoded SHA256 hash
    static func calculateSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
