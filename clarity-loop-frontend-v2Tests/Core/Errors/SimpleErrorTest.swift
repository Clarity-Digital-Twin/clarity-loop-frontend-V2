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
        let networkError = AppError.network(.noConnection)
        let authError = AppError.auth(.invalidCredentials)
        let validationError = AppError.validation(.invalidEmail)
        
        // Then
        XCTAssertEqual(networkError.errorCode, "NET001")
        XCTAssertEqual(authError.userMessage, "Invalid email or password. Please try again.")
        XCTAssertTrue(networkError.isRecoverable)
        XCTAssertTrue(validationError.isRecoverable)
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
    var logs: [(message: String, level: LogLevel)] = []
    
    func log(_ message: String, level: LogLevel, metadata: [String: Any]) {
        logs.append((message, level))
    }
}

final class TestAnalytics: AnalyticsProtocol {
    var events: [(name: String, properties: [String: Any])] = []
    
    func track(event: String, properties: [String: Any]) {
        events.append((event, properties))
    }
}
