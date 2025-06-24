import XCTest

final class ClarityLoopFrontendUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests
        // before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunches() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Verify the app launches and shows login screen
        XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLoginScreenElements() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for login screen to appear
        XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 10))

        // Verify login form elements exist
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Login"].exists)
        XCTAssertTrue(app.buttons["Don't have an account? Register"].exists)
    }
}
