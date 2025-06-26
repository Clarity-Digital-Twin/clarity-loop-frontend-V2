//
//  BaseUITestCase.swift
//  clarity-loop-frontend-v2UITests
//
//  Base class for UI tests providing common functionality
//

import XCTest

/// Base test case for UI tests with common helpers
@MainActor
open class BaseUITestCase: XCTestCase {
    
    // MARK: - Properties
    
    /// The app instance for testing
    private var app: XCUIApplication?
    
    // MARK: - Setup & Teardown
    
    nonisolated open override func setUp() {
        super.setUp()
        Task { @MainActor in
            continueAfterFailure = false
        }
    }
    
    nonisolated open override func tearDown() {
        Task { @MainActor in
            app = nil
        }
        super.tearDown()
    }
    
    // MARK: - App Launch
    
    /// Launch the app with optional launch arguments
    @discardableResult
    public func launchApp(
        with launchArguments: [String] = [],
        environment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        
        // Add default test arguments
        app.launchArguments.append("-UITest")
        app.launchArguments.append("-DisableAnimations")
        
        // Set environment
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        
        app.launch()
        self.app = app
        return app
    }
    
    // MARK: - Element Waiting
    
    /// Wait for an element to exist
    @discardableResult
    public func waitForElement(
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
    
    /// Wait for element to be hittable (visible and interactable)
    @discardableResult
    public func waitForElementToBeHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
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
    
    // MARK: - Element Interaction
    
    /// Tap an element if it exists
    public func tapElement(_ element: XCUIElement) {
        if element.exists && element.isHittable {
            element.tap()
        }
    }
    
    /// Type text into an element
    public func typeText(_ text: String, into element: XCUIElement) {
        if waitForElementToBeHittable(element, timeout: 5) {
            element.tap()
            element.typeText(text)
        }
    }
    
    /// Clear and type text
    public func clearAndTypeText(_ text: String, into element: XCUIElement) {
        if waitForElementToBeHittable(element, timeout: 5) {
            element.tap()
            
            // Select all and delete
            element.press(forDuration: 1.0)
            if let selectAll = app?.menuItems["Select All"].firstMatch {
                if selectAll.waitForExistence(timeout: 2) {
                    selectAll.tap()
                }
            }
            
            element.typeText(String(XCUIKeyboardKey.delete.rawValue))
            element.typeText(text)
        }
    }
    
    // MARK: - Swipe Gestures
    
    /// Swipe up on element
    public func swipeUp(on element: XCUIElement) {
        if element.exists {
            element.swipeUp()
        }
    }
    
    /// Swipe down on element
    public func swipeDown(on element: XCUIElement) {
        if element.exists {
            element.swipeDown()
        }
    }
    
    /// Swipe left on element
    public func swipeLeft(on element: XCUIElement) {
        if element.exists {
            element.swipeLeft()
        }
    }
    
    /// Swipe right on element
    public func swipeRight(on element: XCUIElement) {
        if element.exists {
            element.swipeRight()
        }
    }
    
    // MARK: - Screenshots
    
    /// Take a screenshot with a given name
    @discardableResult
    public func takeScreenshot(name: String) -> XCTAttachment {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return attachment
    }
    
    // MARK: - Accessibility
    
    /// Find element by accessibility identifier
    public func element(
        withAccessibilityIdentifier identifier: String,
        in container: XCUIElement
    ) -> XCUIElement {
        return container.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
    
    /// Find element by label
    public func element(
        withLabel label: String,
        in container: XCUIElement
    ) -> XCUIElement {
        return container.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }
    
    // MARK: - Alert Handling
    
    /// Dismiss any system alerts
    public func dismissAnyAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        
        // Common alert buttons
        let alertButtons = [
            springboard.buttons["Allow"],
            springboard.buttons["OK"],
            springboard.buttons["Dismiss"],
            springboard.buttons["Cancel"],
            springboard.buttons["Don't Allow"]
        ]
        
        for button in alertButtons {
            if button.exists {
                button.tap()
                break
            }
        }
    }
    
    /// Handle permission alerts
    public func handlePermissionAlert(allow: Bool = true) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let button = allow ? springboard.buttons["Allow"] : springboard.buttons["Don't Allow"]
        
        if button.waitForExistence(timeout: 2) {
            button.tap()
        }
    }
    
    // MARK: - Navigation Helpers
    
    /// Go back using navigation bar
    public func navigateBack() {
        guard let app = app else { return }
        
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let backButton = navBar.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
        }
    }
    
    // MARK: - Assertions
    
    /// Assert element exists
    public func assertExists(_ element: XCUIElement, message: String = "") {
        XCTAssertTrue(
            waitForElement(element),
            message.isEmpty ? "Element \(element) should exist" : message
        )
    }
    
    /// Assert element does not exist
    public func assertNotExists(_ element: XCUIElement, message: String = "") {
        XCTAssertFalse(
            element.exists,
            message.isEmpty ? "Element \(element) should not exist" : message
        )
    }
    
    /// Assert element contains text
    public func assertElementContainsText(
        _ element: XCUIElement,
        text: String,
        message: String = ""
    ) {
        assertExists(element)
        let elementText = element.label + (element.value as? String ?? "")
        XCTAssertTrue(
            elementText.contains(text),
            message.isEmpty ? "Element should contain text '\(text)'" : message
        )
    }
}