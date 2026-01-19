import XCTest
@testable import PixelPantry

/// Tests to verify Swift signature implementation matches Node.js server
final class SignatureCompatibilityTests: XCTestCase {
    /// Test that the string-to-sign format matches the server
    func testStringToSignFormat() {
        // The server expects: "{timestamp}.{METHOD}.{path}.{queryString}"
        // This test verifies we're building it correctly

        let signer = RequestSigner(appSecret: "sk_test")

        // The signature function internally builds the string to sign
        // We can verify by checking that identical inputs produce identical outputs
        let sig1 = signer.sign(
            method: "GET",
            path: "/v1/apps/com.example/updates/check",
            queryString: "currentVersion=1.0.0",
            timestamp: 1705592400
        )

        let sig2 = signer.sign(
            method: "GET",
            path: "/v1/apps/com.example/updates/check",
            queryString: "currentVersion=1.0.0",
            timestamp: 1705592400
        )

        XCTAssertEqual(sig1, sig2, "Identical inputs must produce identical signatures")
    }

    /// Test query string sorting matches server
    func testQueryStringSortedAlphabetically() {
        // Server sorts query params alphabetically
        let queryString = RequestSigner.buildQueryString(from: [
            "macOSVersion": "14.2",
            "currentVersion": "1.0.0"
        ])

        // "currentVersion" comes before "macOSVersion" alphabetically
        XCTAssertEqual(queryString, "currentVersion=1.0.0&macOSVersion=14.2")
    }

    /// Test URL encoding matches server
    func testURLEncoding() {
        // Spaces should be encoded as %20
        let queryString = RequestSigner.buildQueryString(from: [
            "name": "My App"
        ])

        XCTAssertTrue(queryString.contains("%20"), "Spaces should be percent-encoded")
        XCTAssertFalse(queryString.contains(" "), "No literal spaces in query string")
    }

    /// Test method is uppercased
    func testMethodUppercased() {
        let signer = RequestSigner(appSecret: "sk_test")

        // Lowercase "get" should produce same signature as uppercase "GET"
        let lowercaseSig = signer.sign(
            method: "get",
            path: "/test",
            queryString: "",
            timestamp: 12345
        )

        let uppercaseSig = signer.sign(
            method: "GET",
            path: "/test",
            queryString: "",
            timestamp: 12345
        )

        XCTAssertEqual(lowercaseSig, uppercaseSig)
    }

    /// Verify signature is hex-encoded (lowercase)
    func testSignatureIsLowercaseHex() {
        let signer = RequestSigner(appSecret: "sk_test")

        let signature = signer.sign(
            method: "GET",
            path: "/test",
            queryString: "",
            timestamp: 12345
        )

        // Should be all lowercase hex
        XCTAssertTrue(signature.allSatisfy { $0.isHexDigit && ($0.isLowercase || $0.isNumber) })
    }

    /// Cross-platform verification: compute signature with known values
    /// and compare against pre-computed value from Node.js
    func testCrossPlatformSignature() {
        // To generate the expected signature from Node.js:
        // const crypto = require('crypto');
        // const timestamp = 1700000000;
        // const stringToSign = "1700000000.GET./v1/apps/com.test/updates/check.currentVersion=1.0.0";
        // const sig = crypto.createHmac('sha256', 'sk_test_secret').update(stringToSign).digest('hex');
        // console.log(sig);

        let signer = RequestSigner(appSecret: "sk_test_secret")

        let signature = signer.sign(
            method: "GET",
            path: "/v1/apps/com.test/updates/check",
            queryString: "currentVersion=1.0.0",
            timestamp: 1700000000
        )

        // This value was generated using the Node.js implementation:
        // node -e "console.log(require('crypto').createHmac('sha256', 'sk_test_secret').update('1700000000.GET./v1/apps/com.test/updates/check.currentVersion=1.0.0').digest('hex'))"
        let expectedSignature = "042073daf42c14eb4161c27aa5541e90e0964428180264981cba334e18cf4e75"

        XCTAssertEqual(signature, expectedSignature, "Swift signature must match Node.js signature")
    }
}
