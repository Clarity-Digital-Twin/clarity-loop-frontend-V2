import XCTest

/// Simple test to establish green baseline
final class SimpleGreenTest: XCTestCase {
    func testSimpleMath() {
        XCTAssertEqual(2 + 2, 4)
    }

    func testSimpleString() {
        let message = "Hello, World!"
        XCTAssertEqual(message, "Hello, World!")
    }

    func testSimpleBoolean() {
        XCTAssertTrue(true)
        XCTAssertFalse(false)
    }
}
