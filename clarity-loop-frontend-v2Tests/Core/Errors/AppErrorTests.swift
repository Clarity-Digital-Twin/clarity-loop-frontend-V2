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
    
    func test_networkError_shouldConvertToAppError() {
        // Given
        let networkErrors: [(NetworkError, AppError)] = [
            (.offline, .network(.connectionFailed)),
            (.invalidURL, .network(.invalidRequest)),
            (.timeout, .network(.timeout)),
            (.serverError(statusCode: 500), .network(.serverError(500))),
            (.decodingFailed("Invalid JSON"), .network(.decodingFailed("Invalid JSON")))
        ]
        
        // Then
        for (networkError, expectedAppError) in networkErrors {
            let appError = AppError.from(networkError)
            XCTAssertEqual(appError, expectedAppError)
        }
    }
    
    func test_authError_shouldConvertToAppError() {
        // Given
        let authErrors: [(AuthError, AppError)] = [
            (.invalidCredentials, .authentication(.invalidCredentials)),
            (.tokenExpired, .authentication(.sessionExpired)),
            (.unauthorized, .authentication(.unauthorized)),
            (.userNotFound, .authentication(.userNotFound)),
            (.networkError("Connection failed"), .network(.connectionFailed))
        ]
        
        // Then
        for (authError, expectedAppError) in authErrors {
            let appError = AppError.from(authError)
            XCTAssertEqual(appError, expectedAppError)
        }
    }
    
    func test_validationError_shouldConvertToAppError() {
        // Given
        let validationErrors: [(ValidationError, AppError)] = [
            (.invalidEmail("test"), .validation(.invalidEmail)),
            (.invalidPassword("short"), .validation(.passwordTooShort)),
            (.fieldRequired("name"), .validation(.requiredFieldMissing("name"))),
            (.invalidFormat("phone", "123"), .validation(.invalidFormat("phone", "123")))
        ]
        
        // Then
        for (validationError, expectedAppError) in validationErrors {
            let appError = AppError.from(validationError)
            XCTAssertEqual(appError, expectedAppError)
        }
    }
    
    // MARK: - Error Context Tests
    
    func test_appError_shouldStoreContext() {
        // Given
        let context = ErrorContext(
            file: "LoginView.swift",
            line: 42,
            function: "performLogin()",
            additionalInfo: ["email": "test@example.com"]
        )
        
        let error = AppError.authentication(.invalidCredentials)
            .withContext(context)
        
        // Then
        XCTAssertEqual(error.context?.file, "LoginView.swift")
        XCTAssertEqual(error.context?.line, 42)
        XCTAssertEqual(error.context?.function, "performLogin()")
        XCTAssertEqual(error.context?.additionalInfo["email"] as? String, "test@example.com")
    }
    
    func test_appError_shouldChainErrors() {
        // Given
        let underlyingError = NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: nil)
        let networkError = NetworkError.connectionFailed(underlyingError)
        let appError = AppError.from(networkError)
            .withUnderlyingError(underlyingError)
        
        // Then
        XCTAssertNotNil(appError.underlyingError)
        XCTAssertEqual((appError.underlyingError as? NSError)?.code, -1009)
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
            .withContext(ErrorContext(
                file: "LoginViewModel.swift",
                line: 75,
                function: "login()",
                additionalInfo: ["email": "user@example.com"]
            ))
        
        // When
        let logMessage = error.logMessage
        
        // Then
        XCTAssertTrue(logMessage.contains("AppError.authentication(.invalidCredentials)"))
        XCTAssertTrue(logMessage.contains("LoginViewModel.swift:75"))
        XCTAssertTrue(logMessage.contains("login()"))
        XCTAssertTrue(logMessage.contains("user@example.com"))
    }
}