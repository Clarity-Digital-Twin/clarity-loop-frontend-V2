//
//  ErrorHandlerTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for centralized error handler
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain

final class ErrorHandlerTests: XCTestCase {
    
    private var errorHandler: ErrorHandler!
    private var mockLogger: MockLogger!
    private var mockAnalytics: MockAnalytics!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockAnalytics = MockAnalytics()
        errorHandler = ErrorHandler(
            logger: mockLogger,
            analytics: mockAnalytics
        )
    }
    
    override func tearDown() {
        errorHandler = nil
        mockLogger = nil
        mockAnalytics = nil
        super.tearDown()
    }
    
    // MARK: - Basic Error Handling
    
    func test_handleError_shouldLogError() {
        // Given
        let error = AppError.network(.connectionFailed)
        
        // When
        errorHandler.handle(error)
        
        // Then
        XCTAssertEqual(mockLogger.loggedMessages.count, 1)
        XCTAssertTrue(mockLogger.loggedMessages.first?.message.contains("connectionFailed") ?? false)
        XCTAssertEqual(mockLogger.loggedMessages.first?.level, .warning)
    }
    
    func test_handleError_shouldTrackAnalytics() {
        // Given
        let error = AppError.authentication(.invalidCredentials)
        
        // When
        errorHandler.handle(error)
        
        // Then
        XCTAssertEqual(mockAnalytics.trackedEvents.count, 1)
        XCTAssertEqual(mockAnalytics.trackedEvents.first?.name, "error_occurred")
        XCTAssertEqual(mockAnalytics.trackedEvents.first?.properties["error_type"] as? String, "authentication")
        XCTAssertEqual(mockAnalytics.trackedEvents.first?.properties["error_code"] as? Int, 2001)
    }
    
    func test_handleError_withContext_shouldIncludeErrorTypeInLog() {
        // Given
        let error = AppError.authentication(.invalidCredentials)
        
        // When
        errorHandler.handle(error)
        
        // Then
        let logMessage = mockLogger.loggedMessages.first?.message ?? ""
        XCTAssertTrue(logMessage.contains("authentication(.invalidCredentials)"))
    }
    
    // MARK: - User Notification Tests
    
    @MainActor
    func test_presentToUser_shouldReturnUserFriendlyMessage() async {
        // Given
        let error = AppError.network(.timeout)
        
        // When
        let presentation = await errorHandler.presentToUser(error)
        
        // Then
        XCTAssertEqual(presentation.title, "Connection Error")
        XCTAssertEqual(presentation.message, "The request timed out. Please try again.")
        XCTAssertEqual(presentation.actions.count, 1)
        XCTAssertEqual(presentation.actions.first?.title, "Retry")
    }
    
    @MainActor
    func test_presentToUser_withRecoverableError_shouldProvideRecoveryActions() async {
        // Given
        let error = AppError.authentication(.sessionExpired)
        
        // When
        let presentation = await errorHandler.presentToUser(error)
        
        // Then
        XCTAssertEqual(presentation.title, "Session Expired")
        XCTAssertEqual(presentation.message, "Your session has expired. Please log in again.")
        XCTAssertEqual(presentation.actions.count, 2)
        XCTAssertEqual(presentation.actions[0].title, "Log In")
        XCTAssertEqual(presentation.actions[0].style, .primary)
        XCTAssertEqual(presentation.actions[1].title, "Cancel")
        XCTAssertEqual(presentation.actions[1].style, .cancel)
    }
    
    @MainActor
    func test_presentToUser_withNonRecoverableError_shouldOnlyHaveDismissAction() async {
        // Given
        let error = AppError.persistence(.corruptedData)
        
        // When
        let presentation = await errorHandler.presentToUser(error)
        
        // Then
        XCTAssertEqual(presentation.title, "Data Error")
        XCTAssertEqual(presentation.actions.count, 1)
        XCTAssertEqual(presentation.actions.first?.title, "OK")
        XCTAssertEqual(presentation.actions.first?.style, .cancel)
    }
    
    // MARK: - Error Recovery Tests
    
    func test_attemptRecovery_withRetryAction_shouldCallRetryHandler() async {
        // Given
        let error = AppError.network(.connectionFailed)
        var retryCalled = false
        errorHandler.setRetryHandler { _ in
            retryCalled = true
        }
        
        // When
        await errorHandler.attemptRecovery(from: error, action: .retry)
        
        // Then
        XCTAssertTrue(retryCalled)
    }
    
    func test_attemptRecovery_withReAuthAction_shouldCallAuthHandler() async {
        // Given
        let error = AppError.authentication(.sessionExpired)
        var reauthCalled = false
        errorHandler.setReAuthHandler {
            reauthCalled = true
        }
        
        // When
        await errorHandler.attemptRecovery(from: error, action: .reAuthenticate)
        
        // Then
        XCTAssertTrue(reauthCalled)
    }
    
    // MARK: - Error Aggregation Tests
    
    func test_errorHandler_shouldAggregateErrors() {
        // Given
        let errors = [
            AppError.network(.connectionFailed),
            AppError.network(.connectionFailed),
            AppError.network(.timeout)
        ]
        
        // When
        errors.forEach { errorHandler.handle($0) }
        let summary = errorHandler.getErrorSummary(since: Date().addingTimeInterval(-60))
        
        // Then
        XCTAssertEqual(summary.totalErrors, 3)
        XCTAssertEqual(summary.errorsByType["network.connectionFailed"], 2)
        XCTAssertEqual(summary.errorsByType["network.timeout"], 1)
    }
    
    func test_errorHandler_shouldTrackErrorRate() {
        // Given
        let startTime = Date()
        
        // When
        errorHandler.handle(AppError.network(.connectionFailed))
        Thread.sleep(forTimeInterval: 0.1)
        errorHandler.handle(AppError.network(.timeout))
        
        let rate = errorHandler.getErrorRate(since: startTime)
        
        // Then
        XCTAssertGreaterThan(rate, 0)
        XCTAssertLessThanOrEqual(rate, 20) // Max 20 errors per second
    }
    
    // MARK: - Critical Error Tests
    
    func test_criticalError_shouldTriggerEmergencyHandler() {
        // Given
        var emergencyHandlerCalled = false
        errorHandler.setEmergencyHandler { error in
            emergencyHandlerCalled = true
        }
        
        let criticalError = AppError.persistence(.corruptedData)
        
        // When
        errorHandler.handleCritical(criticalError)
        
        // Then
        XCTAssertTrue(emergencyHandlerCalled)
        XCTAssertEqual(mockLogger.loggedMessages.first?.level, .error)
        XCTAssertTrue(mockAnalytics.trackedEvents.contains { $0.name == "critical_error" })
    }
    
    // MARK: - Mock Classes
    
    private class MockLogger: LoggerProtocol {
        struct LoggedMessage {
            let message: String
            let level: AppError.LogLevel
            let metadata: [String: Any]
        }
        
        var loggedMessages: [LoggedMessage] = []
        
        func log(_ message: String, level: AppError.LogLevel, metadata: [String: Any]) {
            loggedMessages.append(LoggedMessage(
                message: message,
                level: level,
                metadata: metadata
            ))
        }
    }
    
    private class MockAnalytics: AnalyticsProtocol {
        struct TrackedEvent {
            let name: String
            let properties: [String: Any]
        }
        
        var trackedEvents: [TrackedEvent] = []
        
        func track(event: String, properties: [String: Any]) {
            trackedEvents.append(TrackedEvent(
                name: event,
                properties: properties
            ))
        }
    }
}