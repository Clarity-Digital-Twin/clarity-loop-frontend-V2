//
//  BaseScreen.swift
//  clarity-loop-frontend-v2UITests
//
//  Base class for all screen objects
//

import XCTest

/// Base class for screen objects providing common functionality
@MainActor
class BaseScreen {
    
    // MARK: - Properties
    
    /// The app instance
    let app: XCUIApplication
    
    /// Screen identifier for logging/debugging
    var screenName: String {
        return String(describing: type(of: self))
    }
    
    // MARK: - Initialization
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - Common Elements
    
    /// Navigation bar
    var navigationBar: XCUIElement {
        app.navigationBars.firstMatch
    }
    
    /// Back button in navigation bar
    var backButton: XCUIElement {
        navigationBar.buttons.firstMatch
    }
    
    /// Tab bar
    var tabBar: XCUIElement {
        app.tabBars.firstMatch
    }
    
    // MARK: - Common Actions
    
    /// Navigate back using navigation bar
    func navigateBack() {
        if backButton.exists {
            backButton.tap()
        }
    }
    
    /// Swipe up on screen
    func swipeUp() {
        app.swipeUp()
    }
    
    /// Swipe down on screen
    func swipeDown() {
        app.swipeDown()
    }
    
    /// Pull to refresh
    func pullToRefresh() {
        let firstCell = app.cells.firstMatch
        if firstCell.exists {
            firstCell.swipeDown()
        } else {
            app.swipeDown()
        }
    }
    
    /// Dismiss keyboard
    func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            // Try tapping "Done" button first
            let doneButton = app.toolbars.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            } else {
                // Fallback: tap outside keyboard
                app.tap()
            }
        }
    }
    
    // MARK: - Waiting Helpers
    
    /// Wait for any element to exist
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        )
        
        return result == .completed
    }
    
    /// Wait for element to not exist
    @discardableResult
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        )
        
        return result == .completed
    }
    
    /// Wait for any loading indicator to disappear
    @discardableResult
    func waitForLoadingToComplete(timeout: TimeInterval = 30) -> Bool {
        let loadingIndicators = app.activityIndicators
        let predicate = NSPredicate(format: "count == 0")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: loadingIndicators
        )
        
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        )
        
        return result == .completed
    }
    
    // MARK: - Screenshot
    
    /// Take screenshot with screen name
    @discardableResult
    func takeScreenshot(suffix: String = "") -> XCTAttachment {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = suffix.isEmpty ? screenName : "\(screenName)_\(suffix)"
        attachment.lifetime = .keepAlways
        return attachment
    }
}