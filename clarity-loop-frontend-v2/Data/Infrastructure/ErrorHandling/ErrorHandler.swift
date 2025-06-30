//
//  UpdatedErrorHandler.swift
//  clarity-loop-frontend-v2
//
//  Updated centralized error handling system for new AppError structure
//

import Foundation
import SwiftUI
import ClarityCore
import ClarityDomain

// MARK: - Protocols

public protocol LoggerProtocol: Sendable {
    func log(_ message: String, level: LogLevel, metadata: [String: Any])
}

public protocol AnalyticsProtocol: Sendable {
    func track(event: String, properties: [String: Any])
}

// MARK: - Log Level

public enum LogLevel: String, Sendable {
    case info
    case warning
    case error
}

// MARK: - Recovery Action

public enum RecoveryAction: Sendable {
    case retry
    case reAuthenticate
    case correctInput
}


// MARK: - Error Presentation

@MainActor
public struct ErrorPresentation: Sendable {
    public let title: String
    public let message: String
    public let actions: [ErrorAction]
    
    public struct ErrorAction: Sendable {
        public let title: String
        public let style: ActionStyle
        public let handler: (@Sendable () async -> Void)?
        
        public enum ActionStyle: Sendable {
            case primary
            case cancel
            case destructive
        }
        
        public init(title: String, style: ActionStyle, handler: (@Sendable () async -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }
    
    public init(title: String, message: String, actions: [ErrorAction]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

// MARK: - Error Summary

public struct ErrorSummary: Sendable {
    public let totalErrors: Int
    public let errorsByType: [String: Int]
    public let timeRange: TimeInterval
    public let criticalErrors: Int
}

// MARK: - Error Handler

public final class ErrorHandler: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger: LoggerProtocol
    private let analytics: AnalyticsProtocol
    private let errorQueue = DispatchQueue(label: "com.clarity.errorhandler", attributes: .concurrent)
    
    private var errorHistory: [(error: AppError, timestamp: Date)] = []
    private let historyLock = NSLock()
    
    // Recovery handlers
    private var retryHandler: (@Sendable (AppError) async -> Void)?
    private var reAuthHandler: (@Sendable () async -> Void)?
    private var emergencyHandler: (@Sendable (AppError) -> Void)?
    
    // MARK: - Initialization
    
    public init(logger: LoggerProtocol, analytics: AnalyticsProtocol) {
        self.logger = logger
        self.analytics = analytics
    }
    
    // MARK: - Error Handling
    
    public func handle(_ error: AppError) {
        // Log the error
        let logLevel = LogLevel(from: error.severity)
        logger.log(
            error.logInfo,
            level: logLevel,
            metadata: buildMetadata(for: error)
        )
        
        // Track analytics
        analytics.track(
            event: "error_occurred",
            properties: [
                "error_type": getErrorType(error),
                "error_subtype": getErrorSubtype(error),
                "error_code": error.errorCode,
                "is_recoverable": error.isRecoverable,
                "severity": error.severity.rawValue
            ]
        )
        
        // Store in history
        addToHistory(error)
    }
    
    public func handle(_ error: AppErrorWithContext) {
        // Extract context and handle base error
        var metadata = buildMetadata(for: error.error)
        for (key, value) in error.context {
            metadata[key] = value
        }
        
        let logLevel = LogLevel(from: error.severity)
        logger.log(
            error.logInfo,
            level: logLevel,
            metadata: metadata
        )
        
        analytics.track(
            event: "error_occurred",
            properties: [
                "error_type": getErrorType(error.error),
                "error_subtype": getErrorSubtype(error.error),
                "error_code": error.errorCode,
                "is_recoverable": error.isRecoverable,
                "severity": error.severity.rawValue,
                "has_context": true
            ]
        )
        
        addToHistory(error.error)
    }
    
    public func handleCritical(_ error: AppError) {
        // Log as critical
        logger.log(
            "CRITICAL: \(error.logInfo)",
            level: .error,
            metadata: buildMetadata(for: error)
        )
        
        // Track critical event
        analytics.track(
            event: "critical_error",
            properties: [
                "error_type": getErrorType(error),
                "error_subtype": getErrorSubtype(error),
                "error_code": error.errorCode,
                "error_message": error.userMessage
            ]
        )
        
        // Call emergency handler if set
        emergencyHandler?(error)
        
        // Store in history
        addToHistory(error)
    }
    
    // MARK: - User Presentation
    
    @MainActor
    public func presentToUser(_ error: AppError) async -> ErrorPresentation {
        let title = getErrorTitle(for: error)
        let message = error.userMessage
        let actions = buildActions(for: error)
        
        return ErrorPresentation(
            title: title,
            message: message,
            actions: actions
        )
    }
    
    @MainActor
    public func presentToUser(_ error: AppErrorWithContext) async -> ErrorPresentation {
        return await presentToUser(error.error)
    }
    
    // MARK: - Recovery
    
    @MainActor
    public func attemptRecovery(from error: AppError, action: RecoveryAction) async {
        switch action {
        case .retry:
            await retryHandler?(error)
        case .reAuthenticate:
            await reAuthHandler?()
        case .correctInput:
            // Input correction is handled by the UI
            break
        }
    }
    
    // MARK: - Handler Configuration
    
    public func setRetryHandler(_ handler: @escaping @Sendable (AppError) async -> Void) {
        self.retryHandler = handler
    }
    
    public func setReAuthHandler(_ handler: @escaping @Sendable () async -> Void) {
        self.reAuthHandler = handler
    }
    
    public func setEmergencyHandler(_ handler: @escaping @Sendable (AppError) -> Void) {
        self.emergencyHandler = handler
    }
    
    // MARK: - Error Statistics
    
    public func getErrorSummary(since date: Date) -> ErrorSummary {
        historyLock.lock()
        defer { historyLock.unlock() }
        
        let relevantErrors = errorHistory.filter { $0.timestamp >= date }
        var errorsByType: [String: Int] = [:]
        var criticalCount = 0
        
        for (error, _) in relevantErrors {
            let type = "\(getErrorType(error)).\(getErrorSubtype(error))"
            errorsByType[type, default: 0] += 1
            
            if error.severity == .critical {
                criticalCount += 1
            }
        }
        
        return ErrorSummary(
            totalErrors: relevantErrors.count,
            errorsByType: errorsByType,
            timeRange: Date().timeIntervalSince(date),
            criticalErrors: criticalCount
        )
    }
    
    public func getErrorRate(since date: Date) -> Double {
        historyLock.lock()
        defer { historyLock.unlock() }
        
        let relevantErrors = errorHistory.filter { $0.timestamp >= date }
        let timeInterval = Date().timeIntervalSince(date)
        
        guard timeInterval > 0 else { return 0 }
        return Double(relevantErrors.count) / timeInterval
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ error: AppError) {
        historyLock.lock()
        defer { historyLock.unlock() }
        
        errorHistory.append((error, Date()))
        
        // Keep only last 1000 errors to prevent memory issues
        if errorHistory.count > 1000 {
            errorHistory.removeFirst(errorHistory.count - 1000)
        }
    }
    
    private func buildMetadata(for error: AppError) -> [String: Any] {
        var metadata: [String: Any] = [
            "error_type": getErrorType(error),
            "error_subtype": getErrorSubtype(error),
            "error_code": error.errorCode,
            "severity": error.severity.rawValue
        ]
        
        // Add specific metadata based on error type
        switch error {
        case .network(.serverError(let code)):
            metadata["http_status_code"] = code
        case .validation(.missingRequiredField(let field)):
            metadata["field_name"] = field
        case .validation(.valueOutOfRange(let field, let min, let max)):
            metadata["field_name"] = field
            metadata["min_value"] = min
            metadata["max_value"] = max
        default:
            break
        }
        
        return metadata
    }
    
    private func getErrorType(_ error: AppError) -> String {
        switch error {
        case .network:
            return "network"
        case .auth:
            return "auth"
        case .validation:
            return "validation"
        case .persistence:
            return "persistence"
        case .healthKit:
            return "healthKit"
        case .unknown:
            return "unknown"
        }
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    private func getErrorSubtype(_ error: AppError) -> String {
        switch error {
        case .network(let type):
            switch type {
            case .noConnection:
                return "noConnection"
            case .timeout:
                return "timeout"
            case .serverError:
                return "serverError"
            case .unauthorized:
                return "unauthorized"
            case .notFound:
                return "notFound"
            case .invalidResponse:
                return "invalidResponse"
            }
        case .auth(let type):
            switch type {
            case .invalidCredentials:
                return "invalidCredentials"
            case .sessionExpired:
                return "sessionExpired"
            case .biometricFailed:
                return "biometricFailed"
            case .biometricNotAvailable:
                return "biometricNotAvailable"
            case .tooManyAttempts:
                return "tooManyAttempts"
            case .accountLocked:
                return "accountLocked"
            case .emailNotVerified:
                return "emailNotVerified"
            }
        case .validation(let type):
            switch type {
            case .invalidEmail:
                return "invalidEmail"
            case .passwordTooShort:
                return "passwordTooShort"
            case .passwordTooWeak:
                return "passwordTooWeak"
            case .missingRequiredField:
                return "missingRequiredField"
            case .invalidDateRange:
                return "invalidDateRange"
            case .valueOutOfRange:
                return "valueOutOfRange"
            }
        case .persistence(let type):
            switch type {
            case .saveFailure:
                return "saveFailure"
            case .fetchFailure:
                return "fetchFailure"
            case .deleteFailure:
                return "deleteFailure"
            case .migrationFailure:
                return "migrationFailure"
            case .encryptionFailure:
                return "encryptionFailure"
            case .storageQuotaExceeded:
                return "storageQuotaExceeded"
            }
        case .healthKit(let type):
            switch type {
            case .authorizationDenied:
                return "authorizationDenied"
            case .dataNotAvailable:
                return "dataNotAvailable"
            case .syncFailure:
                return "syncFailure"
            case .invalidDataType:
                return "invalidDataType"
            }
        case .unknown:
            return "unknown"
        }
    }
    
    @MainActor
    private func getErrorTitle(for error: AppError) -> String {
        switch error {
        case .network:
            return "Connection Error"
        case .auth(.sessionExpired):
            return "Session Expired"
        case .auth:
            return "Authentication Error"
        case .validation:
            return "Invalid Input"
        case .persistence:
            return "Data Error"
        case .healthKit:
            return "Health Data Error"
        case .unknown:
            return "Error"
        }
    }
    
    @MainActor
    private func buildActions(for error: AppError) -> [ErrorPresentation.ErrorAction] {
        var actions: [ErrorPresentation.ErrorAction] = []
        
        // Add recovery action if available
        if let recoveryAction = getSuggestedRecoveryAction(for: error) {
            switch recoveryAction {
            case .retry:
                actions.append(ErrorPresentation.ErrorAction(
                    title: "Retry",
                    style: .primary,
                    handler: { [weak self] in
                        await self?.attemptRecovery(from: error, action: .retry)
                    }
                ))
            case .reAuthenticate:
                actions.append(ErrorPresentation.ErrorAction(
                    title: "Log In",
                    style: .primary,
                    handler: { [weak self] in
                        await self?.attemptRecovery(from: error, action: .reAuthenticate)
                    }
                ))
            case .correctInput:
                // Input correction is handled by the form
                break
            }
        }
        
        // Always add a dismiss/cancel action
        let dismissTitle = actions.isEmpty ? "OK" : "Cancel"
        actions.append(ErrorPresentation.ErrorAction(
            title: dismissTitle,
            style: .cancel,
            handler: nil
        ))
        
        return actions
    }
    
    private func getSuggestedRecoveryAction(for error: AppError) -> RecoveryAction? {
        switch error {
        case .network:
            return .retry
        case .auth(.sessionExpired), .auth(.invalidCredentials):
            return .reAuthenticate
        case .validation:
            return .correctInput
        default:
            return nil
        }
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

// MARK: - Default Logger Implementation

public struct ConsoleLogger: LoggerProtocol {
    public init() {}
    
    public func log(_ message: String, level: LogLevel, metadata: [String: Any]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let metadataString = metadata.isEmpty ? "" : " | \(metadata)"
        print("[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\(metadataString)")
    }
}

// MARK: - Default Analytics Implementation

public struct NoOpAnalytics: AnalyticsProtocol {
    public init() {}
    
    public func track(event: String, properties: [String: Any]) {
        // No-op implementation for when analytics is not needed
        #if DEBUG
        print("[Analytics] Event: \(event), Properties: \(properties)")
        #endif
    }
}