//
//  ScreenshotComparisonTests.swift
//  clarity-loop-frontend-v2UITests
//
//  Tests for screenshot comparison functionality
//

import XCTest

@MainActor
final class ScreenshotComparisonTests: BaseUITestCase {
    
    // MARK: - Screenshot Comparison Tests
    
    func test_screenshotComparison_canTakeScreenshot() {
        // Given
        let app = launchApp()
        let comparison = ScreenshotComparison()
        
        // When/Then - should not throw
        XCTAssertNoThrow(
            try comparison.compareScreenshot(
                name: "test_screenshot",
                app: app,
                record: true
            )
        )
    }
    
    func test_screenshotComparison_throwsWhenReferenceNotFound() {
        // Given
        let app = launchApp()
        let comparison = ScreenshotComparison()
        
        // When/Then
        XCTAssertThrowsError(
            try comparison.compareScreenshot(
                name: "nonexistent_screenshot",
                app: app,
                record: false
            )
        ) { error in
            XCTAssertTrue(error is ScreenshotError)
            if case ScreenshotError.referenceNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent_screenshot")
            }
        }
    }
    
    func test_assertScreenshotMatches_recordMode() {
        // Given
        let app = launchApp()
        
        // When/Then - should not fail in record mode
        assertScreenshotMatches(
            app,
            name: "launch_screen",
            record: true
        )
    }
    
    func test_screenshotComparison_generatesAttachment() {
        // Given
        let app = launchApp()
        let screenshot = app.screenshot()
        let comparison = ScreenshotComparison()
        
        // When
        let attachment = comparison.generateDiffImage(
            current: screenshot,
            reference: screenshot,
            name: "diff_test"
        )
        
        // Then
        XCTAssertEqual(attachment.name, "Diff_diff_test")
        XCTAssertEqual(attachment.lifetime, .keepAlways)
    }
    
    func test_screenshotComparison_respectsTolerance() {
        // Given
        let highTolerance = ScreenshotComparison(tolerance: 0.99)
        let lowTolerance = ScreenshotComparison(tolerance: 0.50)
        
        // Then - just verify initialization
        XCTAssertNotNil(highTolerance)
        XCTAssertNotNil(lowTolerance)
    }
}
