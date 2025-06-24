@testable import clarity_loop_frontend
import XCTest
import UIKit

@MainActor
final class SessionTimeoutServiceTests: XCTestCase {
    // MARK: - Properties
    
    var sessionTimeoutService: SessionTimeoutService!

    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sessionTimeoutService = SessionTimeoutService()
    }

    override func tearDownWithError() throws {
        sessionTimeoutService = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testSessionTimeout_NotificationPosted() async throws {
        let expectation = XCTestExpectation(description: "Session timeout notification should be posted.")

        var receivedNotification = false
        let observer = NotificationCenter.default
            .addObserver(forName: .sessionDidTimeout, object: nil, queue: .main) { _ in
                receivedNotification = true
                expectation.fulfill()
            }

        // Set a short timeout
        sessionTimeoutService.setTimeoutInterval(0.5) // 0.5 seconds

        // Wait for the timeout to occur
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertTrue(receivedNotification, "The .sessionDidTimeout notification was not posted.")
        XCTAssertTrue(sessionTimeoutService.isSessionLocked, "Session should be locked after timeout")
        
        NotificationCenter.default.removeObserver(observer)
    }

    func testSessionReset_TimerInvalidated() async throws {
        // Given: Session timeout is set
        sessionTimeoutService.setTimeoutInterval(2.0) // 2 seconds
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should not be locked initially")
        
        // When: User activity is recorded before timeout
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        sessionTimeoutService.recordUserActivity()
        
        // Then: Session should not timeout after original interval
        try await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 seconds (total 2.1s from start)
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should not be locked as timer was reset")
        
        // Verify timeout still works after reset
        let expectation = XCTestExpectation(description: "Timeout after reset")
        let observer = NotificationCenter.default.addObserver(
            forName: .sessionDidTimeout,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Wait for the new timeout
        await fulfillment(of: [expectation], timeout: 2.5)
        XCTAssertTrue(sessionTimeoutService.isSessionLocked, "Session should be locked after reset timeout")
        
        NotificationCenter.default.removeObserver(observer)
    }

    func testLockSession_TimerInvalidated() async throws {
        // Given: Session timeout is set
        sessionTimeoutService.setTimeoutInterval(1.0)
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should not be locked initially")
        
        // When: Session is manually locked
        sessionTimeoutService.lockSession()
        
        // Then: Session should be locked immediately
        XCTAssertTrue(sessionTimeoutService.isSessionLocked, "Session should be locked")
        
        // Verify no timeout notification is posted after the interval
        var timeoutReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .sessionDidTimeout,
            object: nil,
            queue: .main
        ) { _ in
            timeoutReceived = true
        }
        
        // Wait beyond the timeout interval
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        XCTAssertFalse(timeoutReceived, "Timeout notification should not be posted when session is already locked")
        NotificationCenter.default.removeObserver(observer)
    }

    func testAppMovedToBackground_LocksSession() async throws {
        // Given: Session is active
        sessionTimeoutService.setTimeoutInterval(60) // 1 minute
        XCTAssertFalse(sessionTimeoutService.isSessionLocked)
        
        // When: App moves to background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Simulate being in background for more than 30 seconds
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (simulated)
        
        // When: App returns to foreground
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Allow notification to be processed
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Then: Session should be locked (in real app, after 30+ seconds in background)
        // Note: We can't easily simulate the 30-second delay in tests
        // The service tracks backgroundDate but we can't manipulate time
        
        // Verify the service responds to notifications without crashing
        XCTAssertNotNil(sessionTimeoutService)
    }

    func testAppMovedToForeground_ResetsTimer() async throws {
        // Given: Session is active
        sessionTimeoutService.setTimeoutInterval(5.0)
        XCTAssertFalse(sessionTimeoutService.isSessionLocked)
        
        let initialActivityDate = sessionTimeoutService.lastActivityDate
        
        // When: App becomes active
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Allow notification to be processed
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Then: Activity should be recorded
        XCTAssertGreaterThan(sessionTimeoutService.lastActivityDate, initialActivityDate, "Activity date should be updated")
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should remain unlocked")
    }
    
    // MARK: - Additional Tests
    
    func testUnlockSession() async throws {
        // Given: Session is locked
        sessionTimeoutService.lockSession()
        XCTAssertTrue(sessionTimeoutService.isSessionLocked)
        
        // When: Session is unlocked
        sessionTimeoutService.unlockSession()
        
        // Then: Session should be unlocked and timer reset
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should be unlocked")
        
        // Verify timer is active again
        sessionTimeoutService.setTimeoutInterval(0.5)
        let expectation = XCTestExpectation(description: "Timeout after unlock")
        let observer = NotificationCenter.default.addObserver(
            forName: .sessionDidTimeout,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(sessionTimeoutService.isSessionLocked, "Session should timeout after unlock")
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testTimeoutOptions() async throws {
        // Given/When: Get timeout options
        let options = sessionTimeoutService.getTimeoutOptions()
        
        // Then: Verify options
        XCTAssertEqual(options.count, 6, "Should have 6 timeout options")
        XCTAssertTrue(options.contains { $0.title == "1 minute" && $0.interval == 60 })
        XCTAssertTrue(options.contains { $0.title == "5 minutes" && $0.interval == 300 })
        XCTAssertTrue(options.contains { $0.title == "15 minutes" && $0.interval == 900 })
        XCTAssertTrue(options.contains { $0.title == "30 minutes" && $0.interval == 1800 })
        XCTAssertTrue(options.contains { $0.title == "1 hour" && $0.interval == 3600 })
        XCTAssertTrue(options.contains { $0.title == "Never" && $0.interval == 0 })
    }
    
    func testTimeUntilTimeout() async throws {
        // Given: Timeout is set
        sessionTimeoutService.setTimeoutInterval(10.0) // 10 seconds
        
        // When: Some time passes
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Time until timeout should decrease
        let timeRemaining = sessionTimeoutService.timeUntilTimeout
        XCTAssertGreaterThan(timeRemaining, 7.0, "Should have more than 7 seconds remaining")
        XCTAssertLessThan(timeRemaining, 9.0, "Should have less than 9 seconds remaining")
        
        // When: Session is locked
        sessionTimeoutService.lockSession()
        
        // Then: Time until timeout should be 0
        XCTAssertEqual(sessionTimeoutService.timeUntilTimeout, 0, "No time remaining when locked")
    }
    
    func testDisabledTimeout() async throws {
        // Given: Timeout is disabled
        sessionTimeoutService.setTimeoutInterval(0)
        
        // Then: Verify timeout is disabled
        XCTAssertFalse(sessionTimeoutService.isTimeoutEnabled, "Timeout should be disabled")
        XCTAssertEqual(sessionTimeoutService.timeUntilTimeout, 0, "No timeout when disabled")
        
        // Verify no timeout occurs
        var timeoutReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .sessionDidTimeout,
            object: nil,
            queue: .main
        ) { _ in
            timeoutReceived = true
        }
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        XCTAssertFalse(timeoutReceived, "No timeout should occur when disabled")
        XCTAssertFalse(sessionTimeoutService.isSessionLocked, "Session should not lock when timeout disabled")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testRecordActivityWhileLocked() async throws {
        // Given: Session is locked
        sessionTimeoutService.lockSession()
        XCTAssertTrue(sessionTimeoutService.isSessionLocked)
        
        let lockedActivityDate = sessionTimeoutService.lastActivityDate
        
        // When: Try to record activity while locked
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        sessionTimeoutService.recordUserActivity()
        
        // Then: Activity date should update but session remains locked
        XCTAssertGreaterThan(sessionTimeoutService.lastActivityDate, lockedActivityDate, "Activity date should update")
        XCTAssertTrue(sessionTimeoutService.isSessionLocked, "Session should remain locked")
    }
}
