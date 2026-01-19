import XCTest
@testable import PixelPantry

final class UpdateModelTests: XCTestCase {
    func testUpdateFileSizeFormatted() {
        // Test various file sizes
        let smallUpdate = Update(
            version: "1.0.0",
            releaseNotes: "Test",
            minimumMacOS: "13.0",
            fileSize: 1024,
            sha256: "abc",
            downloadPath: "/test"
        )
        XCTAssertFalse(smallUpdate.fileSizeFormatted.isEmpty)

        let mediumUpdate = Update(
            version: "1.0.0",
            releaseNotes: "Test",
            minimumMacOS: "13.0",
            fileSize: 15_728_640, // ~15 MB
            sha256: "abc",
            downloadPath: "/test"
        )
        XCTAssertTrue(mediumUpdate.fileSizeFormatted.contains("MB"))

        let unknownUpdate = Update(
            version: "1.0.0",
            releaseNotes: "Test",
            minimumMacOS: "13.0",
            fileSize: nil,
            sha256: nil,
            downloadPath: "/test"
        )
        XCTAssertEqual(unknownUpdate.fileSizeFormatted, "Unknown size")
    }

    func testUpdateEquality() {
        let update1 = Update(
            version: "1.0.0",
            releaseNotes: "Notes",
            minimumMacOS: "13.0",
            fileSize: 1000,
            sha256: "abc",
            downloadPath: "/path"
        )

        let update2 = Update(
            version: "1.0.0",
            releaseNotes: "Notes",
            minimumMacOS: "13.0",
            fileSize: 1000,
            sha256: "abc",
            downloadPath: "/path"
        )

        let update3 = Update(
            version: "1.1.0",
            releaseNotes: "Notes",
            minimumMacOS: "13.0",
            fileSize: 1000,
            sha256: "abc",
            downloadPath: "/path"
        )

        XCTAssertEqual(update1, update2)
        XCTAssertNotEqual(update1, update3)
    }

    func testUpdateCheckResultHelpers() {
        let update = Update(
            version: "1.2.0",
            releaseNotes: "Test",
            minimumMacOS: "13.0",
            fileSize: 1000,
            sha256: "abc",
            downloadPath: "/test"
        )

        // Test available
        let available: UpdateCheckResult = .available(update)
        XCTAssertTrue(available.isUpdateAvailable)
        XCTAssertNotNil(available.update)
        XCTAssertNil(available.error)

        // Test upToDate
        let upToDate: UpdateCheckResult = .upToDate
        XCTAssertFalse(upToDate.isUpdateAvailable)
        XCTAssertNil(upToDate.update)
        XCTAssertNil(upToDate.error)

        // Test error
        let errorResult: UpdateCheckResult = .error(.networkError(message: "Test"))
        XCTAssertFalse(errorResult.isUpdateAvailable)
        XCTAssertNil(errorResult.update)
        XCTAssertNotNil(errorResult.error)
    }
}
