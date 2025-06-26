//
//  BaseUITestCaseTests.swift
//  clarity-loop-frontend-v2UITests
//
//  TDD tests for BaseUITestCase functionality
//

import XCTest

@MainActor
final class BaseUITestCaseTests: XCTestCase {
    
    // MARK: - Test BaseUITestCase Functionality
    
    func test_baseUITestCase_providesAppLaunchHelper() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        
        // When
        let app = testCase.launchApp()
        
        // Then
        XCTAssertTrue(app.state == .runningForeground)
        XCTAssertTrue(app.exists)
    }
    
    func test_baseUITestCase_providesElementWaitHelper() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let app = testCase.launchApp()
        
        // When
        let launchScreenExists = testCase.waitForElement(
            app.otherElements["LaunchScreen"],
            timeout: 5
        )
        
        // Then
        XCTAssertTrue(launchScreenExists)
    }
    
    func test_baseUITestCase_providesTapHelper() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let app = testCase.launchApp()
        
        // When/Then - should not crash even if element doesn't exist
        testCase.tapElement(app.buttons["NonExistentButton"])
    }
    
    func test_baseUITestCase_providesScreenshotHelper() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let _ = testCase.launchApp()
        
        // When
        let screenshot = testCase.takeScreenshot(name: "test_screenshot")
        
        // Then
        XCTAssertNotNil(screenshot)
        XCTAssertEqual(screenshot.name, "test_screenshot")
    }
    
    func test_baseUITestCase_providesTextEntryHelper() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let app = testCase.launchApp()
        
        // When/Then - should not crash even if no text field exists
        testCase.typeText("test text", into: app.textFields.firstMatch)
    }
    
    func test_baseUITestCase_providesSwipeHelpers() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let app = testCase.launchApp()
        
        // When/Then - should not crash
        testCase.swipeUp(on: app)
        testCase.swipeDown(on: app)
        testCase.swipeLeft(on: app)
        testCase.swipeRight(on: app)
    }
    
    func test_baseUITestCase_providesAccessibilityHelpers() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let app = testCase.launchApp()
        
        // When
        let element = testCase.element(withAccessibilityIdentifier: "test_id", in: app)
        
        // Then
        XCTAssertNotNil(element)
    }
    
    func test_baseUITestCase_providesAlertHandling() throws {
        // Given
        class TestCase: BaseUITestCase {}
        let testCase = TestCase()
        let _ = testCase.launchApp()
        
        // When/Then - should handle alerts gracefully
        testCase.dismissAnyAlerts()
    }
}