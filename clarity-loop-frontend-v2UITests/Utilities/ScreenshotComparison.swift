//
//  ScreenshotComparison.swift
//  clarity-loop-frontend-v2UITests
//
//  Screenshot comparison utilities for visual regression testing
//

import XCTest

/// Utility for comparing screenshots in UI tests
@MainActor
final class ScreenshotComparison {
    
    // MARK: - Properties
    
    /// Tolerance for pixel differences (0.0 - 1.0)
    private let tolerance: Double
    
    /// Directory for reference screenshots
    private let referenceDirectory: String
    
    // MARK: - Initialization
    
    init(tolerance: Double = 0.98, referenceDirectory: String = "ReferenceScreenshots") {
        self.tolerance = tolerance
        self.referenceDirectory = referenceDirectory
    }
    
    // MARK: - Screenshot Comparison
    
    /// Compare current screenshot with reference
    func compareScreenshot(
        name: String,
        app: XCUIApplication,
        record: Bool = false
    ) throws -> Bool {
        // Take current screenshot
        let currentScreenshot = app.screenshot()
        
        if record {
            // Save as reference screenshot
            try saveReferenceScreenshot(currentScreenshot, name: name)
            return true
        } else {
            // Load reference and compare
            guard let referenceScreenshot = loadReferenceScreenshot(name: name) else {
                throw ScreenshotError.referenceNotFound(name)
            }
            
            return compareScreenshots(
                current: currentScreenshot,
                reference: referenceScreenshot
            )
        }
    }
    
    /// Compare two screenshots with tolerance
    private func compareScreenshots(current: XCUIScreenshot, reference: XCUIScreenshot) -> Bool {
        // In a real implementation, this would:
        // 1. Convert images to pixel data
        // 2. Compare pixel by pixel
        // 3. Calculate difference percentage
        // 4. Return true if within tolerance
        
        // For now, return true as a placeholder
        // Real implementation would use Core Graphics or Vision framework
        // to compare pixel data between screenshots
        return true
    }
    
    // MARK: - File Management
    
    /// Save screenshot as reference
    private func saveReferenceScreenshot(_ screenshot: XCUIScreenshot, name: String) throws {
        // Create attachment for test report
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Reference_\(name)"
        attachment.lifetime = .keepAlways
        
        // In a real implementation, this would save to disk
        // For now, we'll just attach to test results
        XCTContext.runActivity(named: "Save Reference Screenshot") { activity in
            activity.add(attachment)
        }
    }
    
    /// Load reference screenshot
    private func loadReferenceScreenshot(name: String) -> XCUIScreenshot? {
        // In a real implementation, this would load from disk
        // For now, return nil to indicate not found
        return nil
    }
    
    // MARK: - Helpers
    
    /// Generate diff image highlighting differences
    func generateDiffImage(
        current: XCUIScreenshot,
        reference: XCUIScreenshot,
        name: String
    ) -> XCTAttachment {
        // In a real implementation, this would:
        // 1. Create a diff image with highlighted differences
        // 2. Red pixels for differences, original for matches
        
        // For now, just attach the current screenshot
        let attachment = XCTAttachment(screenshot: current)
        attachment.name = "Diff_\(name)"
        attachment.lifetime = .keepAlways
        
        return attachment
    }
}

// MARK: - Error Types

enum ScreenshotError: LocalizedError {
    case referenceNotFound(String)
    case comparisonFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .referenceNotFound(let name):
            return "Reference screenshot not found: \(name)"
        case .comparisonFailed(let name):
            return "Screenshot comparison failed: \(name)"
        case .saveFailed(let name):
            return "Failed to save screenshot: \(name)"
        }
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Assert screenshots match
    @MainActor
    func assertScreenshotMatches(
        _ app: XCUIApplication,
        name: String,
        tolerance: Double = 0.98,
        record: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let comparison = ScreenshotComparison(tolerance: tolerance)
        
        do {
            let matches = try comparison.compareScreenshot(
                name: name,
                app: app,
                record: record
            )
            
            if record {
                XCTContext.runActivity(named: "Recorded reference screenshot: \(name)") { _ in }
            } else {
                XCTAssertTrue(
                    matches,
                    "Screenshot '\(name)' does not match reference",
                    file: file,
                    line: line
                )
            }
        } catch {
            XCTFail(
                "Screenshot comparison failed: \(error.localizedDescription)",
                file: file,
                line: line
            )
        }
    }
}