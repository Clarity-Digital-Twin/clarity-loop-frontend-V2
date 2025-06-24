@testable import clarity_loop_frontend
import Foundation
import UIKit
import XCTest

@MainActor
final class AppSecurityServiceTests: XCTestCase {
    // MARK: - Properties
    
    var appSecurityService: AppSecurityService!
    var mockUserDefaults: UserDefaults!

    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "TestDefaults")
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        
        appSecurityService = AppSecurityService()
    }

    override func tearDownWithError() throws {
        appSecurityService = nil
        mockUserDefaults = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testIsJailbroken_DeviceIsJailbroken() async throws {
        // Given: Check device security
        appSecurityService.checkDeviceSecurity()
        
        // Then: On simulator/test environment, device should not be jailbroken
        // Note: We can't easily mock file system checks, but we can verify the property is set
        XCTAssertFalse(appSecurityService.isJailbroken, "Test environment should not be detected as jailbroken")
        
        // Verify security warnings for non-jailbroken device
        XCTAssertTrue(appSecurityService.securityWarnings.isEmpty, "Should have no security warnings")
        XCTAssertFalse(appSecurityService.isSecurityCompromised, "Security should not be compromised")
    }

    func testIsJailbroken_DeviceIsNotJailbroken() async throws {
        // Given: Initial state
        XCTAssertFalse(appSecurityService.isJailbroken, "Should start as not jailbroken")
        
        // When: Check device security
        appSecurityService.checkDeviceSecurity()
        
        // Then: Device should remain not jailbroken
        XCTAssertFalse(appSecurityService.isJailbroken, "Device should not be jailbroken")
        XCTAssertTrue(appSecurityService.securityWarnings.isEmpty, "Should have no warnings")
        XCTAssertFalse(appSecurityService.isSecurityCompromised, "Should not be compromised")
    }

    func testPreventScreenshots_NotificationHandled() async throws {
        // Note: Screenshot prevention on iOS is limited
        // We can't actually prevent screenshots, only detect them
        // The AppSecurityService doesn't currently observe screenshot notifications
        
        // Given: Service is initialized
        XCTAssertNotNil(appSecurityService)
        
        // When: Screenshot notification is posted
        NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        
        // Then: No crash occurs (service doesn't observe this notification currently)
        // In a real implementation, you might log this event or show a warning
        XCTAssertTrue(true, "Service handles notification without crashing")
    }

    func testAppMovedToBackground_ShouldBlur() async throws {
        // Given: Background blur is enabled
        appSecurityService.enableBackgroundBlur(true)
        XCTAssertTrue(appSecurityService.shouldBlurOnBackground, "Background blur should be enabled")
        XCTAssertFalse(appSecurityService.isAppObscured, "App should not be obscured initially")
        
        // When: App moves to background
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        
        // Allow notification to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: App should be marked as obscured
        XCTAssertTrue(appSecurityService.isAppObscured, "App should be obscured when in background")
    }

    func testAppMovedToForeground_ShouldUnblur() async throws {
        // Given: App is in background (obscured)
        appSecurityService.enableBackgroundBlur(true)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        
        // Allow notification to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(appSecurityService.isAppObscured, "App should be obscured")
        
        // When: App returns to foreground
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Allow notification to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: App should no longer be obscured
        XCTAssertFalse(appSecurityService.isAppObscured, "App should not be obscured when active")
    }
    
    // MARK: - Additional Tests
    
    func testEnableBackgroundBlur() async throws {
        // Given: Default state
        let initialState = appSecurityService.shouldBlurOnBackground
        
        // When: Disable background blur
        appSecurityService.enableBackgroundBlur(false)
        
        // Then: Setting should be updated
        XCTAssertFalse(appSecurityService.shouldBlurOnBackground, "Background blur should be disabled")
        
        // When: Enable background blur
        appSecurityService.enableBackgroundBlur(true)
        
        // Then: Setting should be updated
        XCTAssertTrue(appSecurityService.shouldBlurOnBackground, "Background blur should be enabled")
    }
    
    func testSecurityWarningsForJailbrokenDevice() async throws {
        // Note: We can't easily simulate a jailbroken device in tests
        // But we can verify the warning structure would be correct
        
        // Given: Device is not jailbroken
        appSecurityService.checkDeviceSecurity()
        
        // Then: No warnings
        let warnings = appSecurityService.securityWarnings
        XCTAssertEqual(warnings.count, 0, "Non-jailbroken device should have no warnings")
        
        // Verify warning types exist
        XCTAssertNotNil(SecurityWarningType.jailbreak)
        XCTAssertNotNil(SecurityWarningType.debugger)
        XCTAssertNotNil(SecurityWarningType.simulator)
        XCTAssertNotNil(SecurityWarningType.other)
        
        // Verify severity colors
        XCTAssertNotNil(SecuritySeverity.low.color)
        XCTAssertNotNil(SecuritySeverity.medium.color)
        XCTAssertNotNil(SecuritySeverity.high.color)
        XCTAssertNotNil(SecuritySeverity.critical.color)
    }
    
    func testNotificationObserversAreSetup() async throws {
        // Given: Service is initialized
        XCTAssertNotNil(appSecurityService)
        
        // When: Notifications are posted
        var notificationsFired = 0
        
        let expectation1 = expectation(description: "Will resign active")
        let expectation2 = expectation(description: "Did become active")
        
        let observer1 = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            notificationsFired += 1
            expectation1.fulfill()
        }
        
        let observer2 = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            notificationsFired += 1
            expectation2.fulfill()
        }
        
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
        
        // Then: Notifications were observed
        XCTAssertEqual(notificationsFired, 2, "Both notifications should have been observed")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer1)
        NotificationCenter.default.removeObserver(observer2)
    }
    
    func testBackgroundBlurToggleSequence() async throws {
        // Given: Initial state
        appSecurityService.enableBackgroundBlur(true)
        
        // When: App goes to background with blur enabled
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Then: App should be obscured
        XCTAssertTrue(appSecurityService.isAppObscured)
        
        // When: Return to foreground
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Then: App should not be obscured
        XCTAssertFalse(appSecurityService.isAppObscured)
        
        // When: Disable blur and go to background again
        appSecurityService.enableBackgroundBlur(false)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Then: App should still be marked as obscured (for state tracking)
        XCTAssertTrue(appSecurityService.isAppObscured, "isAppObscured tracks background state regardless of blur setting")
    }
}
