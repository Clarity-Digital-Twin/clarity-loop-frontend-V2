//
//  AppError.swift
//  clarity-loop-frontend-v2
//
//  Comprehensive error types for all application layers
//

import Foundation

/// Main application error type that encompasses all error categories
public enum AppError: Error, Equatable, @unchecked Sendable {
    case network(NetworkErrorType)
    case persistence(PersistenceErrorType)
    case validation(ValidationErrorType)
    case auth(AuthErrorType)
    case healthKit(HealthKitErrorType)
    case unknown
    
    // MARK: - Network Error Types
    
    public enum NetworkErrorType: Equatable {
        case noConnection
        case timeout
        case serverError(Int)
        case unauthorized
        case notFound
        case invalidResponse
    }
    
    // MARK: - Persistence Error Types
    
    public enum PersistenceErrorType: Equatable {
        case saveFailure
        case fetchFailure
        case deleteFailure
        case migrationFailure
        case encryptionFailure
        case storageQuotaExceeded
    }
    
    // MARK: - Validation Error Types
    
    public enum ValidationErrorType: Equatable {
        case invalidEmail
        case passwordTooShort
        case passwordTooWeak
        case missingRequiredField(String)
        case invalidDateRange
        case valueOutOfRange(String, min: Int, max: Int)
    }
    
    // MARK: - Auth Error Types
    
    public enum AuthErrorType: Equatable {
        case invalidCredentials
        case sessionExpired
        case biometricFailed
        case biometricNotAvailable
        case tooManyAttempts
        case accountLocked
        case emailNotVerified
    }
    
    // MARK: - HealthKit Error Types
    
    public enum HealthKitErrorType: Equatable {
        case authorizationDenied
        case dataNotAvailable
        case syncFailure
        case invalidDataType
    }
    
    // MARK: - User Messages
    
    /// User-friendly error message
    public var userMessage: String {
        switch self {
        case .network(let type):
            return type.userMessage
        case .persistence(let type):
            return type.userMessage
        case .validation(let type):
            return type.userMessage
        case .auth(let type):
            return type.userMessage
        case .healthKit(let type):
            return type.userMessage
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    // MARK: - Error Codes
    
    /// Unique error code for tracking and debugging
    public var errorCode: String {
        switch self {
        case .network(let type):
            return type.errorCode
        case .persistence(let type):
            return type.errorCode
        case .validation(let type):
            return type.errorCode
        case .auth(let type):
            return type.errorCode
        case .healthKit(let type):
            return type.errorCode
        case .unknown:
            return "UNK001"
        }
    }
    
    // MARK: - Error Properties
    
    /// Whether the error is recoverable by retrying
    public var isRecoverable: Bool {
        switch self {
        case .network(.serverError(let code)):
            return code >= 500
        case .network:
            return true
        case .persistence(.migrationFailure):
            return false
        case .persistence:
            return true
        case .validation:
            return true
        case .auth(.accountLocked):
            return false
        case .auth:
            return true
        case .healthKit:
            return true
        case .unknown:
            return true
        }
    }
    
    /// Severity level of the error
    public var severity: ErrorSeverity {
        switch self {
        case .network:
            return .medium
        case .persistence(.migrationFailure):
            return .critical
        case .persistence:
            return .high
        case .validation:
            return .low
        case .auth(.accountLocked), .auth(.tooManyAttempts):
            return .high
        case .auth:
            return .high
        case .healthKit:
            return .medium
        case .unknown:
            return .medium
        }
    }
    
    // MARK: - Localization
    
    /// Localization key for translating error messages
    public var localizationKey: String {
        switch self {
        case .network(let type):
            return "error.network.\(type.localizationSuffix)"
        case .persistence(let type):
            return "error.persistence.\(type.localizationSuffix)"
        case .validation(let type):
            return "error.validation.\(type.localizationSuffix)"
        case .auth(let type):
            return "error.auth.\(type.localizationSuffix)"
        case .healthKit(let type):
            return "error.healthKit.\(type.localizationSuffix)"
        case .unknown:
            return "error.unknown"
        }
    }
    
    /// Get localized message for specific locale
    public func localizedMessage(locale: String) -> String {
        // In production, this would use NSLocalizedString
        // For now, return the default user message
        return userMessage
    }
    
    // MARK: - Context
    
    /// Create a contextualized error wrapper
    public func withContext(_ context: [String: Any]) -> AppErrorWithContext {
        return AppErrorWithContext(error: self, context: context)
    }
    
    // MARK: - Logging
    
    /// Information suitable for logging
    public var logInfo: String {
        return """
        AppError: \(errorCode)
        Type: \(self)
        Message: \(userMessage)
        Severity: \(severity)
        Recoverable: \(isRecoverable)
        Context: N/A
        """
    }
    
    // MARK: - Error Conversion
    
    /// Convert from underlying system errors
    public static func from(_ error: Error) -> AppError {
        switch error {
        case let urlError as URLError:
            return .from(urlError)
        case let nsError as NSError:
            return .from(nsError)
        default:
            return .unknown
        }
    }
    
    private static func from(_ urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .network(.noConnection)
        case .timedOut:
            return .network(.timeout)
        case .userAuthenticationRequired:
            return .network(.unauthorized)
        default:
            return .network(.invalidResponse)
        }
    }
    
    private static func from(_ nsError: NSError) -> AppError {
        // Keychain errors
        if nsError.domain == "NSOSStatusErrorDomain" {
            switch nsError.code {
            case -25300, -25299: // Item not found, duplicate item
                return .persistence(.saveFailure)
            case -25308: // User interaction not allowed
                return .persistence(.encryptionFailure)
            default:
                return .persistence(.fetchFailure)
            }
        }
        
        return .unknown
    }
}

// MARK: - Error Severity

public enum ErrorSeverity: String, CaseIterable {
    case low
    case medium
    case high
    case critical
}

// MARK: - Network Error Extensions

extension AppError.NetworkErrorType {
    var userMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "The request timed out. Please try again."
        case .serverError:
            return "Server error. Please try again later."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .notFound:
            return "The requested resource was not found."
        case .invalidResponse:
            return "Received invalid response from server."
        }
    }
    
    var errorCode: String {
        switch self {
        case .noConnection:
            return "NET001"
        case .timeout:
            return "NET002"
        case .serverError:
            return "NET003"
        case .unauthorized:
            return "NET004"
        case .notFound:
            return "NET005"
        case .invalidResponse:
            return "NET006"
        }
    }
    
    var localizationSuffix: String {
        switch self {
        case .noConnection:
            return "no_connection"
        case .timeout:
            return "timeout"
        case .serverError:
            return "server_error"
        case .unauthorized:
            return "unauthorized"
        case .notFound:
            return "not_found"
        case .invalidResponse:
            return "invalid_response"
        }
    }
}

// MARK: - Persistence Error Extensions

extension AppError.PersistenceErrorType {
    var userMessage: String {
        switch self {
        case .saveFailure:
            return "Failed to save data. Please try again."
        case .fetchFailure:
            return "Failed to load data. Please try again."
        case .deleteFailure:
            return "Failed to delete data. Please try again."
        case .migrationFailure:
            return "Database update failed. Please restart the app."
        case .encryptionFailure:
            return "Failed to secure data. Please try again."
        case .storageQuotaExceeded:
            return "Storage limit exceeded. Please free up space."
        }
    }
    
    var errorCode: String {
        switch self {
        case .saveFailure:
            return "PER001"
        case .fetchFailure:
            return "PER002"
        case .deleteFailure:
            return "PER003"
        case .migrationFailure:
            return "PER004"
        case .encryptionFailure:
            return "PER005"
        case .storageQuotaExceeded:
            return "PER006"
        }
    }
    
    var localizationSuffix: String {
        switch self {
        case .saveFailure:
            return "save_failure"
        case .fetchFailure:
            return "fetch_failure"
        case .deleteFailure:
            return "delete_failure"
        case .migrationFailure:
            return "migration_failure"
        case .encryptionFailure:
            return "encryption_failure"
        case .storageQuotaExceeded:
            return "storage_quota_exceeded"
        }
    }
}

// MARK: - Validation Error Extensions

extension AppError.ValidationErrorType {
    var userMessage: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .passwordTooShort:
            return "Password must be at least 8 characters long."
        case .passwordTooWeak:
            return "Password must contain uppercase, lowercase, and numbers."
        case .missingRequiredField(let field):
            return "\(field) is required."
        case .invalidDateRange:
            return "End date must be after start date."
        case .valueOutOfRange(let field, let min, let max):
            return "\(field) must be between \(min) and \(max)."
        }
    }
    
    var errorCode: String {
        switch self {
        case .invalidEmail:
            return "VAL001"
        case .passwordTooShort:
            return "VAL002"
        case .passwordTooWeak:
            return "VAL003"
        case .missingRequiredField:
            return "VAL004"
        case .invalidDateRange:
            return "VAL005"
        case .valueOutOfRange:
            return "VAL006"
        }
    }
    
    var localizationSuffix: String {
        switch self {
        case .invalidEmail:
            return "invalid_email"
        case .passwordTooShort:
            return "password_too_short"
        case .passwordTooWeak:
            return "password_too_weak"
        case .missingRequiredField:
            return "missing_required_field"
        case .invalidDateRange:
            return "invalid_date_range"
        case .valueOutOfRange:
            return "value_out_of_range"
        }
    }
}

// MARK: - Auth Error Extensions

extension AppError.AuthErrorType {
    var userMessage: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .biometricFailed:
            return "Biometric authentication failed. Please try again."
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device."
        case .tooManyAttempts:
            return "Too many failed attempts. Please try again later."
        case .accountLocked:
            return "Your account has been locked. Please contact support."
        case .emailNotVerified:
            return "Please verify your email address first."
        }
    }
    
    var errorCode: String {
        switch self {
        case .invalidCredentials:
            return "AUTH001"
        case .sessionExpired:
            return "AUTH002"
        case .biometricFailed:
            return "AUTH003"
        case .biometricNotAvailable:
            return "AUTH004"
        case .tooManyAttempts:
            return "AUTH005"
        case .accountLocked:
            return "AUTH006"
        case .emailNotVerified:
            return "AUTH007"
        }
    }
    
    var localizationSuffix: String {
        switch self {
        case .invalidCredentials:
            return "invalid_credentials"
        case .sessionExpired:
            return "session_expired"
        case .biometricFailed:
            return "biometric_failed"
        case .biometricNotAvailable:
            return "biometric_not_available"
        case .tooManyAttempts:
            return "too_many_attempts"
        case .accountLocked:
            return "account_locked"
        case .emailNotVerified:
            return "email_not_verified"
        }
    }
}

// MARK: - HealthKit Error Extensions

extension AppError.HealthKitErrorType {
    var userMessage: String {
        switch self {
        case .authorizationDenied:
            return "Health data access denied. Please enable in Settings."
        case .dataNotAvailable:
            return "Health data is not available."
        case .syncFailure:
            return "Failed to sync health data. Please try again."
        case .invalidDataType:
            return "This health data type is not supported."
        }
    }
    
    var errorCode: String {
        switch self {
        case .authorizationDenied:
            return "HK001"
        case .dataNotAvailable:
            return "HK002"
        case .syncFailure:
            return "HK003"
        case .invalidDataType:
            return "HK004"
        }
    }
    
    var localizationSuffix: String {
        switch self {
        case .authorizationDenied:
            return "authorization_denied"
        case .dataNotAvailable:
            return "data_not_available"
        case .syncFailure:
            return "sync_failure"
        case .invalidDataType:
            return "invalid_data_type"
        }
    }
}

// MARK: - AppError With Context

/// Wrapper for AppError with additional context
public struct AppErrorWithContext: Error, @unchecked Sendable {
    public let error: AppError
    public let context: [String: Any]
    
    public init(error: AppError, context: [String: Any]) {
        self.error = error
        self.context = context
    }
    
    /// Forward properties from the underlying error
    public var userMessage: String { error.userMessage }
    public var errorCode: String { error.errorCode }
    public var isRecoverable: Bool { error.isRecoverable }
    public var severity: ErrorSeverity { error.severity }
    public var localizationKey: String { error.localizationKey }
    
    public func localizedMessage(locale: String) -> String {
        error.localizedMessage(locale: locale)
    }
    
    /// Enhanced log info with context
    public var logInfo: String {
        return """
        AppError: \(error.errorCode)
        Type: \(error)
        Message: \(error.userMessage)
        Severity: \(error.severity)
        Recoverable: \(error.isRecoverable)
        Context: \(context)
        """
    }
}
