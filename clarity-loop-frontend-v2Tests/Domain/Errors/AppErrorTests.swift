//
//  AppErrorTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for comprehensive error types across all application layers
//

import Testing
import Foundation
@testable import ClarityDomain

@Suite("AppError Tests")
struct AppErrorTests {
    
    // MARK: - Network Error Tests
    
    @Test("Network errors should have appropriate user messages")
    func testNetworkErrorMessages() {
        // Test each network error case
        let errors: [(AppError, String)] = [
            (.network(.noConnection), "No internet connection. Please check your network settings."),
            (.network(.timeout), "The request timed out. Please try again."),
            (.network(.serverError(500)), "Server error. Please try again later."),
            (.network(.unauthorized), "Your session has expired. Please log in again."),
            (.network(.notFound), "The requested resource was not found."),
            (.network(.invalidResponse), "Received invalid response from server.")
        ]
        
        for (error, expectedMessage) in errors {
            #expect(error.userMessage == expectedMessage)
        }
    }
    
    @Test("Network errors should have unique error codes")
    func testNetworkErrorCodes() {
        let errors: [(AppError, String)] = [
            (.network(.noConnection), "NET001"),
            (.network(.timeout), "NET002"),
            (.network(.serverError(500)), "NET003"),
            (.network(.unauthorized), "NET004"),
            (.network(.notFound), "NET005"),
            (.network(.invalidResponse), "NET006")
        ]
        
        for (error, expectedCode) in errors {
            #expect(error.errorCode == expectedCode)
        }
    }
    
    // MARK: - Persistence Error Tests
    
    @Test("Persistence errors should have appropriate user messages")
    func testPersistenceErrorMessages() {
        let errors: [(AppError, String)] = [
            (.persistence(.saveFailure), "Failed to save data. Please try again."),
            (.persistence(.fetchFailure), "Failed to load data. Please try again."),
            (.persistence(.deleteFailure), "Failed to delete data. Please try again."),
            (.persistence(.migrationFailure), "Database update failed. Please restart the app."),
            (.persistence(.encryptionFailure), "Failed to secure data. Please try again."),
            (.persistence(.storageQuotaExceeded), "Storage limit exceeded. Please free up space.")
        ]
        
        for (error, expectedMessage) in errors {
            #expect(error.userMessage == expectedMessage)
        }
    }
    
    @Test("Persistence errors should have unique error codes")
    func testPersistenceErrorCodes() {
        let errors: [(AppError, String)] = [
            (.persistence(.saveFailure), "PER001"),
            (.persistence(.fetchFailure), "PER002"),
            (.persistence(.deleteFailure), "PER003"),
            (.persistence(.migrationFailure), "PER004"),
            (.persistence(.encryptionFailure), "PER005"),
            (.persistence(.storageQuotaExceeded), "PER006")
        ]
        
        for (error, expectedCode) in errors {
            #expect(error.errorCode == expectedCode)
        }
    }
    
    // MARK: - Validation Error Tests
    
    @Test("Validation errors should have appropriate user messages")
    func testValidationErrorMessages() {
        let errors: [(AppError, String)] = [
            (.validation(.invalidEmail), "Please enter a valid email address."),
            (.validation(.passwordTooShort), "Password must be at least 8 characters long."),
            (.validation(.passwordTooWeak), "Password must contain uppercase, lowercase, and numbers."),
            (.validation(.missingRequiredField("Name")), "Name is required."),
            (.validation(.invalidDateRange), "End date must be after start date."),
            (.validation(.valueOutOfRange("Age", min: 0, max: 150)), "Age must be between 0 and 150.")
        ]
        
        for (error, expectedMessage) in errors {
            #expect(error.userMessage == expectedMessage)
        }
    }
    
    @Test("Validation errors should have unique error codes")
    func testValidationErrorCodes() {
        let errors: [(AppError, String)] = [
            (.validation(.invalidEmail), "VAL001"),
            (.validation(.passwordTooShort), "VAL002"),
            (.validation(.passwordTooWeak), "VAL003"),
            (.validation(.missingRequiredField("Name")), "VAL004"),
            (.validation(.invalidDateRange), "VAL005"),
            (.validation(.valueOutOfRange("Age", min: 0, max: 150)), "VAL006")
        ]
        
        for (error, expectedCode) in errors {
            #expect(error.errorCode == expectedCode)
        }
    }
    
    // MARK: - Auth Error Tests
    
    @Test("Auth errors should have appropriate user messages")
    func testAuthErrorMessages() {
        let errors: [(AppError, String)] = [
            (.auth(.invalidCredentials), "Invalid email or password."),
            (.auth(.sessionExpired), "Your session has expired. Please log in again."),
            (.auth(.biometricFailed), "Biometric authentication failed. Please try again."),
            (.auth(.biometricNotAvailable), "Biometric authentication is not available on this device."),
            (.auth(.tooManyAttempts), "Too many failed attempts. Please try again later."),
            (.auth(.accountLocked), "Your account has been locked. Please contact support."),
            (.auth(.emailNotVerified), "Please verify your email address first.")
        ]
        
        for (error, expectedMessage) in errors {
            #expect(error.userMessage == expectedMessage)
        }
    }
    
    @Test("Auth errors should have unique error codes")
    func testAuthErrorCodes() {
        let errors: [(AppError, String)] = [
            (.auth(.invalidCredentials), "AUTH001"),
            (.auth(.sessionExpired), "AUTH002"),
            (.auth(.biometricFailed), "AUTH003"),
            (.auth(.biometricNotAvailable), "AUTH004"),
            (.auth(.tooManyAttempts), "AUTH005"),
            (.auth(.accountLocked), "AUTH006"),
            (.auth(.emailNotVerified), "AUTH007")
        ]
        
        for (error, expectedCode) in errors {
            #expect(error.errorCode == expectedCode)
        }
    }
    
    // MARK: - HealthKit Error Tests
    
    @Test("HealthKit errors should have appropriate user messages")
    func testHealthKitErrorMessages() {
        let errors: [(AppError, String)] = [
            (.healthKit(.authorizationDenied), "Health data access denied. Please enable in Settings."),
            (.healthKit(.dataNotAvailable), "Health data is not available."),
            (.healthKit(.syncFailure), "Failed to sync health data. Please try again."),
            (.healthKit(.invalidDataType), "This health data type is not supported.")
        ]
        
        for (error, expectedMessage) in errors {
            #expect(error.userMessage == expectedMessage)
        }
    }
    
    @Test("HealthKit errors should have unique error codes")
    func testHealthKitErrorCodes() {
        let errors: [(AppError, String)] = [
            (.healthKit(.authorizationDenied), "HK001"),
            (.healthKit(.dataNotAvailable), "HK002"),
            (.healthKit(.syncFailure), "HK003"),
            (.healthKit(.invalidDataType), "HK004")
        ]
        
        for (error, expectedCode) in errors {
            #expect(error.errorCode == expectedCode)
        }
    }
    
    // MARK: - Unknown Error Tests
    
    @Test("Unknown error should have generic message")
    func testUnknownErrorMessage() {
        let error = AppError.unknown
        #expect(error.userMessage == "An unexpected error occurred. Please try again.")
        #expect(error.errorCode == "UNK001")
    }
    
    // MARK: - Error Properties Tests
    
    @Test("All errors should be recoverable except critical ones")
    func testErrorRecoverability() {
        // Most errors should be recoverable
        #expect(AppError.network(.timeout).isRecoverable == true)
        #expect(AppError.validation(.invalidEmail).isRecoverable == true)
        #expect(AppError.auth(.invalidCredentials).isRecoverable == true)
        
        // Critical errors should not be recoverable
        #expect(AppError.persistence(.migrationFailure).isRecoverable == false)
        #expect(AppError.auth(.accountLocked).isRecoverable == false)
    }
    
    @Test("Errors should have appropriate severity levels")
    func testErrorSeverity() {
        // Network errors - medium severity
        #expect(AppError.network(.timeout).severity == .medium)
        
        // Validation errors - low severity
        #expect(AppError.validation(.invalidEmail).severity == .low)
        
        // Auth errors - high severity for security
        #expect(AppError.auth(.accountLocked).severity == .high)
        
        // Persistence migration - critical
        #expect(AppError.persistence(.migrationFailure).severity == .critical)
    }
    
    // MARK: - Localization Tests
    
    @Test("Errors should support localization")
    func testErrorLocalization() {
        let error = AppError.network(.noConnection)
        
        // Test that localization key is properly formed
        #expect(error.localizationKey == "error.network.no_connection")
        
        // Test that error can provide localized message
        // (In real app, this would use NSLocalizedString)
        #expect(error.localizedMessage(locale: "en") == error.userMessage)
    }
    
    // MARK: - Error Context Tests
    
    @Test("Errors should support additional context")
    func testErrorContext() {
        let error = AppError.network(.serverError(500))
        
        // Should be able to add context
        let contextualError = error.withContext([
            "endpoint": "/api/health/metrics",
            "timestamp": "2025-06-30T10:00:00Z"
        ])
        
        #expect(contextualError.context["endpoint"] as? String == "/api/health/metrics")
        #expect(contextualError.context["timestamp"] as? String == "2025-06-30T10:00:00Z")
        
        // Should forward error properties
        #expect(contextualError.errorCode == error.errorCode)
        #expect(contextualError.userMessage == error.userMessage)
        #expect(contextualError.severity == error.severity)
    }
    
    // MARK: - Error Logging Tests
    
    @Test("Errors should provide appropriate logging information")
    func testErrorLogging() {
        let error = AppError.auth(.invalidCredentials)
        
        let logInfo = error.logInfo
        #expect(logInfo.contains("AUTH001"))
        #expect(logInfo.contains("invalidCredentials"))
        #expect(logInfo.contains("severity: high"))
    }
    
    // MARK: - Error Conversion Tests
    
    @Test("Should convert from underlying errors appropriately")
    func testErrorConversion() {
        // Test URLError conversion
        let urlError = URLError(.notConnectedToInternet)
        let appError = AppError.from(urlError)
        #expect(appError == .network(.noConnection))
        
        // Test NSError conversion for Keychain
        let keychainError = NSError(domain: "NSOSStatusErrorDomain", code: -25300)
        let persistenceError = AppError.from(keychainError)
        #expect(persistenceError == .persistence(.encryptionFailure))
    }
}
