//
//  ErrorHandlerTestsSwift.swift
//  clarity-loop-frontend-v2Tests
//
//  Swift Testing tests for updated ErrorHandler
//

import Testing
import Foundation
@testable import ClarityCore
@testable import ClarityDomain

@Suite("Updated ErrorHandler Tests")
struct ErrorHandlerTestsSwift {
    
    // MARK: - Basic Error Handling
    
    @Test("Should log errors with appropriate level")
    func testErrorLogging() async throws {
        // Given
        let mockLogger = MockLogger()
        let mockAnalytics = MockAnalytics()
        let errorHandler = ErrorHandler(logger: mockLogger, analytics: mockAnalytics)
        
        // When: Handle different severity errors
        errorHandler.handle(.network(.timeout))
        errorHandler.handle(.validation(.invalidEmail))
        errorHandler.handle(.auth(.accountLocked))
        
        // Then: Check log levels match severity
        #expect(mockLogger.loggedMessages.count == 3)
        #expect(mockLogger.loggedMessages[0].level == .warning) // medium severity
        #expect(mockLogger.loggedMessages[1].level == .info) // low severity
        #expect(mockLogger.loggedMessages[2].level == .error) // high severity
    }
    
    @Test("Should track analytics for each error")
    func testErrorAnalytics() async throws {
        // Given
        let mockLogger = MockLogger()
        let mockAnalytics = MockAnalytics()
        let errorHandler = ErrorHandler(logger: mockLogger, analytics: mockAnalytics)
        
        // When
        errorHandler.handle(.network(.serverError(500)))
        
        // Then
        #expect(mockAnalytics.trackedEvents.count == 1)
        let event = mockAnalytics.trackedEvents[0]
        #expect(event.name == "error_occurred")
        #expect(event.properties["error_type"] as? String == "network")
        #expect(event.properties["error_subtype"] as? String == "serverError")
        #expect(event.properties["error_code"] as? String == "NET003")
        #expect(event.properties["is_recoverable"] as? Bool == true)
    }
    
    // MARK: - User Presentation Tests
    
    @Test("Should provide user-friendly error presentations")
    @MainActor
    func testUserPresentation() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        
        // When: Present network error
        let networkPresentation = await errorHandler.presentToUser(.network(.noConnection))
        
        // Then
        #expect(networkPresentation.title == "Connection Error")
        #expect(networkPresentation.message == "No internet connection. Please check your network settings.")
        #expect(networkPresentation.actions.count == 2) // Retry + Cancel
        #expect(networkPresentation.actions[0].title == "Retry")
        #expect(networkPresentation.actions[0].style == .primary)
    }
    
    @Test("Should handle auth errors with appropriate actions")
    @MainActor
    func testAuthErrorPresentation() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        
        // When
        let authPresentation = await errorHandler.presentToUser(.auth(.sessionExpired))
        
        // Then
        #expect(authPresentation.title == "Session Expired")
        #expect(authPresentation.message == "Your session has expired. Please log in again.")
        #expect(authPresentation.actions.contains { $0.title == "Log In" })
    }
    
    @Test("Should provide only dismiss action for non-recoverable errors")
    @MainActor
    func testNonRecoverableErrorPresentation() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        
        // When
        let presentation = await errorHandler.presentToUser(.persistence(.migrationFailure))
        
        // Then
        #expect(presentation.actions.count == 1)
        #expect(presentation.actions[0].title == "OK")
        #expect(presentation.actions[0].style == .cancel)
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Should execute retry handler for recoverable errors")
    @MainActor
    func testRetryRecovery() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        var retryCount = 0
        let retryError = AppError.network(.timeout)
        
        errorHandler.setRetryHandler { error in
            #expect(error == retryError)
            retryCount += 1
        }
        
        // When
        await errorHandler.attemptRecovery(from: retryError, action: .retry)
        
        // Then
        #expect(retryCount == 1)
    }
    
    @Test("Should execute reauth handler for auth errors")
    @MainActor
    func testReAuthRecovery() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        var reauthCalled = false
        
        errorHandler.setReAuthHandler {
            reauthCalled = true
        }
        
        // When
        await errorHandler.attemptRecovery(from: .auth(.sessionExpired), action: .reAuthenticate)
        
        // Then
        #expect(reauthCalled == true)
    }
    
    // MARK: - Critical Error Tests
    
    @Test("Should handle critical errors with emergency handler")
    func testCriticalErrorHandling() async throws {
        // Given
        let mockLogger = MockLogger()
        let errorHandler = ErrorHandler(
            logger: mockLogger,
            analytics: MockAnalytics()
        )
        var emergencyCalled = false
        let criticalError = AppError.persistence(.migrationFailure)
        
        errorHandler.setEmergencyHandler { error in
            #expect(error == criticalError)
            emergencyCalled = true
        }
        
        // When
        errorHandler.handleCritical(criticalError)
        
        // Then
        #expect(emergencyCalled == true)
        #expect(mockLogger.loggedMessages.first?.message.contains("CRITICAL"))
    }
    
    // MARK: - Error History Tests
    
    @Test("Should track error history")
    func testErrorHistory() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        let startTime = Date()
        
        // When: Generate several errors
        errorHandler.handle(.network(.timeout))
        errorHandler.handle(.network(.timeout))
        errorHandler.handle(.validation(.invalidEmail))
        errorHandler.handle(.auth(.invalidCredentials))
        
        // Then: Check summary
        let summary = errorHandler.getErrorSummary(since: startTime)
        #expect(summary.totalErrors == 4)
        #expect(summary.errorsByType["network.timeout"] == 2)
        #expect(summary.errorsByType["validation.invalidEmail"] == 1)
        #expect(summary.errorsByType["auth.invalidCredentials"] == 1)
    }
    
    @Test("Should calculate error rate")
    func testErrorRate() async throws {
        // Given
        let errorHandler = ErrorHandler(
            logger: MockLogger(),
            analytics: MockAnalytics()
        )
        let startTime = Date()
        
        // When: Generate errors
        errorHandler.handle(.network(.timeout))
        try? await Task.sleep(for: .milliseconds(100))
        errorHandler.handle(.network(.serverError(500)))
        
        // Then: Calculate rate
        let rate = errorHandler.getErrorRate(since: startTime)
        #expect(rate > 0)
        #expect(rate < 100) // Less than 100 errors per second
    }
    
    // MARK: - Context Handling Tests
    
    @Test("Should handle errors with context")
    func testErrorContext() async throws {
        // Given
        let mockLogger = MockLogger()
        let errorHandler = ErrorHandler(
            logger: mockLogger,
            analytics: MockAnalytics()
        )
        
        // When
        let contextualError = AppError.network(.serverError(500)).withContext([
            "endpoint": "/api/health/metrics",
            "userId": "12345"
        ])
        errorHandler.handle(contextualError)
        
        // Then
        let metadata = mockLogger.loggedMessages.first?.metadata ?? [:]
        #expect(metadata["endpoint"] as? String == "/api/health/metrics")
        #expect(metadata["userId"] as? String == "12345")
    }
}

// MARK: - Mock Implementations

private actor MockLogger: LoggerProtocol {
    struct LoggedMessage {
        let message: String
        let level: LogLevel
        let metadata: [String: Any]
    }
    
    private(set) var loggedMessages: [LoggedMessage] = []
    
    func log(_ message: String, level: LogLevel, metadata: [String: Any]) {
        loggedMessages.append(LoggedMessage(
            message: message,
            level: level,
            metadata: metadata
        ))
    }
}

private actor MockAnalytics: AnalyticsProtocol {
    struct TrackedEvent {
        let name: String
        let properties: [String: Any]
    }
    
    private(set) var trackedEvents: [TrackedEvent] = []
    
    func track(event: String, properties: [String: Any]) {
        trackedEvents.append(TrackedEvent(
            name: event,
            properties: properties
        ))
    }
}

// MARK: - LogLevel Extension

extension LogLevel {
    init(from severity: ErrorSeverity) {
        switch severity {
        case .low:
            self = .info
        case .medium:
            self = .warning
        case .high, .critical:
            self = .error
        }
    }
}