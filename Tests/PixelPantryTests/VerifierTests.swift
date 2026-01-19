import XCTest
@testable import PixelPantry

final class VerifierTests: XCTestCase {
    func testSHA256Calculation() {
        let testData = "Hello, PixelPantry!".data(using: .utf8)!
        let hash = Verifier.calculateSHA256(data: testData)

        // SHA256 should be 64 hex characters
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    func testSHA256Consistency() {
        let data1 = "test data".data(using: .utf8)!
        let data2 = "test data".data(using: .utf8)!

        let hash1 = Verifier.calculateSHA256(data: data1)
        let hash2 = Verifier.calculateSHA256(data: data2)

        XCTAssertEqual(hash1, hash2, "Same data should produce same hash")
    }

    func testSHA256DifferentData() {
        let data1 = "test data 1".data(using: .utf8)!
        let data2 = "test data 2".data(using: .utf8)!

        let hash1 = Verifier.calculateSHA256(data: data1)
        let hash2 = Verifier.calculateSHA256(data: data2)

        XCTAssertNotEqual(hash1, hash2, "Different data should produce different hash")
    }

    func testKnownHash() {
        // Test against a known SHA256 hash
        // "Hello, World!" -> "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = Verifier.calculateSHA256(data: testData)

        XCTAssertEqual(
            hash.lowercased(),
            "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
        )
    }

    func testFileVerification() throws {
        // Create a temp file with known content
        let content = "Test file content for verification"
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).txt")

        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        // Calculate expected hash
        let expectedHash = Verifier.calculateSHA256(data: content.data(using: .utf8)!)

        // Verify file
        let isValid = try Verifier.verifySHA256(fileURL: tempFile, expected: expectedHash)
        XCTAssertTrue(isValid)

        // Verify with wrong hash
        let isInvalid = try Verifier.verifySHA256(fileURL: tempFile, expected: "0".repeated(64))
        XCTAssertFalse(isInvalid)
    }

    func testCaseInsensitiveVerification() throws {
        let content = "Test content"
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).txt")

        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        let hash = Verifier.calculateSHA256(data: content.data(using: .utf8)!)

        // Test lowercase
        XCTAssertTrue(try Verifier.verifySHA256(fileURL: tempFile, expected: hash.lowercased()))

        // Test uppercase
        XCTAssertTrue(try Verifier.verifySHA256(fileURL: tempFile, expected: hash.uppercased()))
    }
}

// Helper extension
private extension String {
    func repeated(_ times: Int) -> String {
        String(repeating: self, count: times)
    }
}
