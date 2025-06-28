//
//  AppError.swift
//  clarity-loop-frontend-v2
//
//  Comprehensive error handling system for the app
//

import Foundation

/// Comprehensive error type that unifies all app errors
public enum AppError: Error, Equatable {
    
    // MARK: - Error Categories
    
    case network(NetworkErrorType)
    case authentication(AuthenticationErrorType)
    case validation(ValidationErrorType)
    case persistence(PersistenceErrorType)
    case unknown(String)
    
    // MARK: - Network Error Types
    
    public enum NetworkErrorType: Equatable, Sendable {
        case connectionFailed
        case timeout
        case serverError(Int)
        case invalidRequest
        case decodingFailed(String)
    }
    
    // MARK: - Authentication Error Types
    
    public enum AuthenticationErrorType: Equatable, Sendable {
        case invalidCredentials
        case sessionExpired
        case unauthorized
        case userNotFound
    }
    
    // MARK: - Validation Error Types
    
    public enum ValidationErrorType: Equatable, Sendable {
        case invalidEmail
        case passwordTooShort
        case requiredFieldMissing(String)
        case invalidFormat(String, String) // field, value
    }
    
    // MARK: - Persistence Error Types
    
    public enum PersistenceErrorType: Equatable, Sendable {
        case dataNotFound
        case saveFailed
        case deleteFailed
        case corruptedData
    }
    
    // MARK: - Properties
    
    public var domain: String {
        "ClarityAppError"
    }
    
    public var code: Int {
        switch self {
        case .network(let type):
            switch type {
            case .connectionFailed: return 1001
            case .timeout: return 1002
            case .serverError: return 1003
            case .invalidRequest: return 1004
            case .decodingFailed: return 1005
            }
            
        case .authentication(let type):
            switch type {
            case .invalidCredentials: return 2001
            case .sessionExpired: return 2002
            case .unauthorized: return 2003
            case .userNotFound: return 2004
            }
            
        case .validation(let type):
            switch type {
            case .invalidEmail: return 3001
            case .passwordTooShort: return 3002
            case .requiredFieldMissing: return 3003
            case .invalidFormat: return 3004
            }
            
        case .persistence(let type):
            switch type {
            case .dataNotFound: return 4001
            case .saveFailed: return 4002
            case .deleteFailed: return 4003
            case .corruptedData: return 4004
            }
            
        case .unknown:
            return 9999
        }
    }
    
    public var userFriendlyMessage: String {
        switch self {
        case .network(let type):
            switch type {
            case .connectionFailed:
                return "Unable to connect to the server. Please check your internet connection."
            case .timeout:
                return "The request timed out. Please try again."
            case .serverError(let code):
                return "Server error (\(code)). Please try again later."
            case .invalidRequest:
                return "Invalid request. Please contact support if this persists."
            case .decodingFailed:
                return "Unable to process server response. Please try again."
            }
            
        case .authentication(let type):
            switch type {
            case .invalidCredentials:
                return "Invalid email or password. Please try again."
            case .sessionExpired:
                return "Your session has expired. Please log in again."
            case .unauthorized:
                return "You are not authorized to perform this action."
            case .userNotFound:
                return "User account not found."
            }
            
        case .validation(let type):
            switch type {
            case .invalidEmail:
                return "Please enter a valid email address."
            case .passwordTooShort:
                return "Password must be at least 8 characters long."
            case .requiredFieldMissing(let field):
                return "\(field.capitalized) is required."
            case .invalidFormat(let field, _):
                return "Invalid \(field) format."
            }
            
        case .persistence(let type):
            switch type {
            case .dataNotFound:
                return "The requested data could not be found."
            case .saveFailed:
                return "Unable to save data. Please try again."
            case .deleteFailed:
                return "Unable to delete data. Please try again."
            case .corruptedData:
                return "Data appears to be corrupted. Please contact support."
            }
            
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    public var isRecoverable: Bool {
        switch self {
        case .network(.connectionFailed), .network(.timeout):
            return true
        case .authentication(.sessionExpired):
            return true
        case .persistence(.saveFailed):
            return true
        default:
            return false
        }
    }
    
    // MARK: - Recovery Action
    
    public enum RecoveryAction: Equatable, Sendable {
        case retry
        case reAuthenticate
        case correctInput
    }
    
    public var suggestedRecoveryAction: RecoveryAction? {
        switch self {
        case .network(.connectionFailed), .network(.timeout):
            return .retry
        case .authentication(.sessionExpired), .authentication(.unauthorized):
            return .reAuthenticate
        case .validation:
            return .correctInput
        case .persistence(.saveFailed):
            return .retry
        default:
            return nil
        }
    }
    
    // MARK: - Logging
    
    public enum LogLevel: String, Sendable {
        case debug
        case info
        case warning
        case error
    }
    
    public var logLevel: LogLevel {
        switch self {
        case .network(.connectionFailed):
            return .warning
        case .network(.serverError):
            return .error
        case .authentication(.invalidCredentials):
            return .info
        case .authentication(.unauthorized):
            return .warning
        case .validation:
            return .debug
        case .persistence(.dataNotFound):
            return .warning
        case .persistence(.corruptedData):
            return .error
        case .unknown:
            return .error
        default:
            return .warning
        }
    }
    
    // MARK: - Context
    // Note: Swift enums cannot have stored properties, so we'll use a different approach
    // Context and underlying errors should be tracked separately by the error handler
    
    public var logMessage: String {
        "AppError.\(self)"
    }
}

// MARK: - Error Context

public struct ErrorContext: Sendable {
    public let file: String
    public let line: Int
    public let function: String
    public let additionalInfo: [String: String] // Changed to String for Sendable
    
    public init(
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        additionalInfo: [String: String] = [:]
    ) {
        self.file = file
        self.line = line
        self.function = function
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Error Conversion

extension AppError {
    
    /// Convert from any Error type
    public static func from(_ error: Error) -> AppError {
        // If it's already an AppError, return it
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert based on error type if we recognize it
        // For now, return unknown with description
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Convenience Error Creation

public extension AppError {
    
    /// Create an error with context in one call
    static func networkError(
        _ type: NetworkErrorType,
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        additionalInfo: [String: String] = [:]
    ) -> AppError {
        AppError.network(type)
    }
    
    /// Create an auth error with context
    static func authError(
        _ type: AuthenticationErrorType,
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        additionalInfo: [String: String] = [:]
    ) -> AppError {
        AppError.authentication(type)
    }
}