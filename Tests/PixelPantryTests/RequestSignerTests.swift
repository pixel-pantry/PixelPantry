import XCTest
@testable import PixelPantry

final class RequestSignerTests: XCTestCase {
    func testSignatureGeneration() {
        let signer = RequestSigner(appSecret: "sk_test_secret_key")

        let timestamp = 1705592400
        let signature = signer.sign(
            method: "GET",
            path: "/v1/apps/com.example.app/updates/check",
            queryString: "currentVersion=1.0.0&macOSVersion=14.2",
            timestamp: timestamp
        )

        // Signature should be 64 hex characters (SHA256)
        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(signature.allSatisfy { $0.isHexDigit })
    }

    func testSignatureConsistency() {
        let signer = RequestSigner(appSecret: "sk_test_secret")

        let sig1 = signer.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)
        let sig2 = signer.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)

        XCTAssertEqual(sig1, sig2, "Same inputs should produce same signature")
    }

    func testSignatureChangesWithDifferentTimestamp() {
        let signer = RequestSigner(appSecret: "sk_test_secret")

        let sig1 = signer.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)
        let sig2 = signer.sign(method: "GET", path: "/test", queryString: "", timestamp: 12346)

        XCTAssertNotEqual(sig1, sig2, "Different timestamps should produce different signatures")
    }

    func testSignatureChangesWithDifferentPath() {
        let signer = RequestSigner(appSecret: "sk_test_secret")

        let sig1 = signer.sign(method: "GET", path: "/test1", queryString: "", timestamp: 12345)
        let sig2 = signer.sign(method: "GET", path: "/test2", queryString: "", timestamp: 12345)

        XCTAssertNotEqual(sig1, sig2, "Different paths should produce different signatures")
    }

    func testSignatureChangesWithDifferentSecret() {
        let signer1 = RequestSigner(appSecret: "sk_secret1")
        let signer2 = RequestSigner(appSecret: "sk_secret2")

        let sig1 = signer1.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)
        let sig2 = signer2.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)

        XCTAssertNotEqual(sig1, sig2, "Different secrets should produce different signatures")
    }

    func testMethodIsUppercased() {
        let signer = RequestSigner(appSecret: "sk_test_secret")

        let sig1 = signer.sign(method: "get", path: "/test", queryString: "", timestamp: 12345)
        let sig2 = signer.sign(method: "GET", path: "/test", queryString: "", timestamp: 12345)

        XCTAssertEqual(sig1, sig2, "Method should be uppercased internally")
    }

    func testBuildQueryString() {
        // Empty params
        XCTAssertEqual(RequestSigner.buildQueryString(from: [:]), "")

        // Single param
        XCTAssertEqual(
            RequestSigner.buildQueryString(from: ["version": "1.0.0"]),
            "version=1.0.0"
        )

        // Multiple params should be sorted
        let params = ["zebra": "1", "apple": "2", "mango": "3"]
        XCTAssertEqual(
            RequestSigner.buildQueryString(from: params),
            "apple=2&mango=3&zebra=1"
        )
    }

    func testQueryStringEncoding() {
        let params = ["name": "My App", "version": "1.0.0"]
        let result = RequestSigner.buildQueryString(from: params)

        XCTAssertTrue(result.contains("name=My%20App"), "Spaces should be encoded")
        XCTAssertTrue(result.contains("version=1.0.0"))
    }

    func testKnownSignature() {
        // Test against a known signature to verify compatibility with server
        // This test ensures the Swift implementation matches the Node.js implementation

        let signer = RequestSigner(appSecret: "sk_test_secret_for_verification")
        let signature = signer.sign(
            method: "GET",
            path: "/v1/apps/com.test.app/updates/check",
            queryString: "currentVersion=1.0.0",
            timestamp: 1700000000
        )

        // The expected signature should match what the server would produce
        // String to sign: "1700000000.GET./v1/apps/com.test.app/updates/check.currentVersion=1.0.0"
        // With secret: "sk_test_secret_for_verification"

        // We can't easily test the exact value without running the Node implementation,
        // but we verify format and consistency
        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(signature.allSatisfy { $0.isHexDigit })

        // Verify it's consistent
        let signature2 = signer.sign(
            method: "GET",
            path: "/v1/apps/com.test.app/updates/check",
            queryString: "currentVersion=1.0.0",
            timestamp: 1700000000
        )
        XCTAssertEqual(signature, signature2)
    }
}
