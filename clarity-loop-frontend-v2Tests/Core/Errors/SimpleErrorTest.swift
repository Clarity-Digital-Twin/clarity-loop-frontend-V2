//
//  SimpleErrorTest.swift
//  clarity-loop-frontend-v2Tests
//
//  Simple test to verify error handling works
//

import XCTest
@testable import ClarityCore

final class SimpleErrorTest: XCTestCase {
    
    func test_appError_canBeCreatedAndUsed() {
        // Given/When
        let networkError = AppError.network(.connectionFailed)
        let authError = AppError.authentication(.invalidCredentials)
        let validationError = AppError.validation(.invalidEmail)
        
        // Then
        XCTAssertEqual(networkError.domain, "ClarityAppError")
        XCTAssertEqual(networkError.code, 1001)
        XCTAssertEqual(authError.userFriendlyMessage, "Invalid email or password. Please try again.")
        XCTAssertTrue(networkError.isRecoverable)
        XCTAssertEqual(validationError.suggestedRecoveryAction, .correctInput)
    }
    
    func test_errorHandler_canBeCreated() {
        // Given
        let logger = TestLogger()
        let analytics = TestAnalytics()
        
        // When
        let errorHandler = ErrorHandler(logger: logger, analytics: analytics)
        let error = AppError.network(.timeout)
        errorHandler.handle(error)
        
        // Then
        XCTAssertEqual(logger.logs.count, 1)
        XCTAssertEqual(analytics.events.count, 1)
    }
}

// Simple test implementations
final class TestLogger: LoggerProtocol {
    var logs: [(message: String, level: AppError.LogLevel)] = []
    
    func log(_ message: String, level: AppError.LogLevel, metadata: [String: Any]) {
        logs.append((message, level))
    }
}

final class TestAnalytics: AnalyticsProtocol {
    var events: [(name: String, properties: [String: Any])] = []
    
    func track(event: String, properties: [String: Any]) {
        events.append((event, properties))
    }
}
