//
//  AppErrorTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for comprehensive error types
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain

final class AppErrorTests: XCTestCase {
    
    // MARK: - AppError Tests
    
    func test_appError_shouldHaveCorrectErrorDomain() {
        // Given
        let error = AppError.network(.connectionFailed)
        
        // Then
        XCTAssertEqual(error.domain, "ClarityAppError")
    }
    
    func test_appError_shouldProvideUserFriendlyMessage() {
        // Given
        let testCases: [(AppError, String)] = [
            (.network(.connectionFailed), "Unable to connect to the server. Please check your internet connection."),
            (.network(.timeout), "The request timed out. Please try again."),
            (.authentication(.invalidCredentials), "Invalid email or password. Please try again."),
            (.authentication(.sessionExpired), "Your session has expired. Please log in again."),
            (.validation(.invalidEmail), "Please enter a valid email address."),
            (.validation(.passwordTooShort), "Password must be at least 8 characters long."),
            (.persistence(.dataNotFound), "The requested data could not be found."),
            (.persistence(.saveFailed), "Unable to save data. Please try again."),
            (.unknown("Custom error"), "An unexpected error occurred: Custom error")
        ]
        
        // Then
        for (error, expectedMessage) in testCases {
            XCTAssertEqual(error.userFriendlyMessage, expectedMessage)
        }
    }
    
    func test_appError_shouldProvideCorrectErrorCode() {
        // Given
        let testCases: [(AppError, Int)] = [
            (.network(.connectionFailed), 1001),
            (.network(.timeout), 1002),
            (.network(.serverError(500)), 1003),
            (.authentication(.invalidCredentials), 2001),
            (.authentication(.sessionExpired), 2002),
            (.authentication(.unauthorized), 2003),
            (.validation(.invalidEmail), 3001),
            (.validation(.passwordTooShort), 3002),
            (.validation(.requiredFieldMissing("name")), 3003),
            (.persistence(.dataNotFound), 4001),
            (.persistence(.saveFailed), 4002),
            (.persistence(.deleteFailed), 4003),
            (.unknown("error"), 9999)
        ]
        
        // Then
        for (error, expectedCode) in testCases {
            XCTAssertEqual(error.code, expectedCode)
        }
    }
    
    func test_appError_shouldBeRecoverable() {
        // Given
        let recoverableErrors: [AppError] = [
            .network(.connectionFailed),
            .network(.timeout),
            .authentication(.sessionExpired),
            .persistence(.saveFailed)
        ]
        
        let nonRecoverableErrors: [AppError] = [
            .authentication(.invalidCredentials),
            .validation(.invalidEmail),
            .unknown("Fatal error")
        ]
        
        // Then
        for error in recoverableErrors {
            XCTAssertTrue(error.isRecoverable, "\(error) should be recoverable")
        }
        
        for error in nonRecoverableErrors {
            XCTAssertFalse(error.isRecoverable, "\(error) should not be recoverable")
        }
    }
    
    func test_appError_shouldProvideRecoveryAction() {
        // Given
        let testCases: [(AppError, AppError.RecoveryAction?)] = [
            (.network(.connectionFailed), .retry),
            (.network(.timeout), .retry),
            (.authentication(.sessionExpired), .reAuthenticate),
            (.authentication(.unauthorized), .reAuthenticate),
            (.validation(.invalidEmail), .correctInput),
            (.persistence(.saveFailed), .retry),
            (.unknown("error"), nil)
        ]
        
        // Then
        for (error, expectedAction) in testCases {
            XCTAssertEqual(error.suggestedRecoveryAction, expectedAction)
        }
    }
    
    // MARK: - Error Conversion Tests
    
    func test_genericError_shouldConvertToAppError() {
        // Given
        let genericError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        let appError = AppError.from(genericError)
        
        // Then
        if case .unknown(let message) = appError {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Expected unknown error")
        }
    }
    
    func test_appError_shouldReturnItself() {
        // Given
        let originalError = AppError.authentication(.invalidCredentials)
        
        // When
        let convertedError = AppError.from(originalError)
        
        // Then
        XCTAssertEqual(convertedError, originalError)
    }
    
    // MARK: - Error Context Tests
    
    func test_errorContext_shouldBeCreatedWithDefaults() {
        // Given/When
        let context = ErrorContext()
        
        // Then
        XCTAssertTrue(context.file.contains(".swift"))
        XCTAssertGreaterThan(context.line, 0)
        XCTAssertFalse(context.function.isEmpty)
        XCTAssertTrue(context.additionalInfo.isEmpty)
    }
    
    // MARK: - Logging Tests
    
    func test_appError_shouldProvideLogLevel() {
        // Given
        let testCases: [(AppError, AppError.LogLevel)] = [
            (.network(.connectionFailed), .warning),
            (.network(.serverError(500)), .error),
            (.authentication(.invalidCredentials), .info),
            (.authentication(.unauthorized), .warning),
            (.validation(.invalidEmail), .debug),
            (.persistence(.dataNotFound), .warning),
            (.persistence(.corruptedData), .error),
            (.unknown("Critical failure"), .error)
        ]
        
        // Then
        for (error, expectedLevel) in testCases {
            XCTAssertEqual(error.logLevel, expectedLevel)
        }
    }
    
    func test_appError_shouldGenerateLogMessage() {
        // Given
        let error = AppError.authentication(.invalidCredentials)
        
        // When
        let logMessage = error.logMessage
        
        // Then
        XCTAssertEqual(logMessage, "AppError.authentication(.invalidCredentials)")
    }
}
