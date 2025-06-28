//
//  ErrorHandler.swift
//  clarity-loop-frontend-v2
//
//  Centralized error handling system
//

import Foundation
import SwiftUI

// MARK: - Protocols

public protocol LoggerProtocol: Sendable {
    func log(_ message: String, level: AppError.LogLevel, metadata: [String: Any])
}

public protocol AnalyticsProtocol: Sendable {
    func track(event: String, properties: [String: Any])
}

// MARK: - Error Presentation

@MainActor
public struct ErrorPresentation {
    public let title: String
    public let message: String
    public let actions: [ErrorAction]
    
    public struct ErrorAction {
        public let title: String
        public let style: ActionStyle
        public let handler: (() async -> Void)?
        
        public enum ActionStyle {
            case primary
            case cancel
            case destructive
        }
    }
}

// MARK: - Error Summary

public struct ErrorSummary {
    public let totalErrors: Int
    public let errorsByType: [String: Int]
    public let timeRange: TimeInterval
    public let criticalErrors: Int
}

// MARK: - Error Handler

public final class ErrorHandler {
    
    // MARK: - Properties
    
    private let logger: LoggerProtocol
    private let analytics: AnalyticsProtocol
    private let errorQueue = DispatchQueue(label: "com.clarity.errorhandler", attributes: .concurrent)
    
    private var errorHistory: [(error: AppError, timestamp: Date)] = []
    private let historyLock = NSLock()
    
    // Recovery handlers
    private var retryHandler: ((AppError) async -> Void)?
    private var reAuthHandler: (() async -> Void)?
    private var emergencyHandler: ((AppError) -> Void)?
    
    // MARK: - Initialization
    
    public init(logger: LoggerProtocol, analytics: AnalyticsProtocol) {
        self.logger = logger
        self.analytics = analytics
    }
    
    // MARK: - Error Handling
    
    public func handle(_ error: AppError) {
        // Log the error
        logger.log(
            error.logMessage,
            level: error.logLevel,
            metadata: buildMetadata(for: error)
        )
        
        // Track analytics
        analytics.track(
            event: "error_occurred",
            properties: [
                "error_type": getErrorType(error),
                "error_code": error.code,
                "is_recoverable": error.isRecoverable
            ]
        )
        
        // Store in history
        addToHistory(error)
    }
    
    public func handleCritical(_ error: AppError) {
        // Log as critical
        logger.log(
            "CRITICAL: \(error.logMessage)",
            level: .error,
            metadata: buildMetadata(for: error)
        )
        
        // Track critical event
        analytics.track(
            event: "critical_error",
            properties: [
                "error_type": getErrorType(error),
                "error_code": error.code,
                "error_message": error.userFriendlyMessage
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
        let message = error.userFriendlyMessage
        let actions = buildActions(for: error)
        
        return ErrorPresentation(
            title: title,
            message: message,
            actions: actions
        )
    }
    
    // MARK: - Recovery
    
    @MainActor
    public func attemptRecovery(from error: AppError, action: AppError.RecoveryAction) async {
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
    
    public func setRetryHandler(_ handler: @escaping (AppError) async -> Void) {
        self.retryHandler = handler
    }
    
    public func setReAuthHandler(_ handler: @escaping () async -> Void) {
        self.reAuthHandler = handler
    }
    
    public func setEmergencyHandler(_ handler: @escaping (AppError) -> Void) {
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
            
            if error.logLevel == .error {
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
        let metadata: [String: Any] = [
            "error_domain": error.domain,
            "error_code": error.code
        ]
        
        // Context should be tracked separately in production code
        // For now, just return basic metadata
        
        return metadata
    }
    
    private func getErrorType(_ error: AppError) -> String {
        switch error {
        case .network: return "network"
        case .authentication: return "authentication"
        case .validation: return "validation"
        case .persistence: return "persistence"
        case .unknown: return "unknown"
        }
    }
    
    private func getErrorSubtype(_ error: AppError) -> String {
        switch error {
        case .network(let type):
            switch type {
            case .connectionFailed: return "connectionFailed"
            case .timeout: return "timeout"
            case .serverError: return "serverError"
            case .invalidRequest: return "invalidRequest"
            case .decodingFailed: return "decodingFailed"
            }
        case .authentication(let type):
            switch type {
            case .invalidCredentials: return "invalidCredentials"
            case .sessionExpired: return "sessionExpired"
            case .unauthorized: return "unauthorized"
            case .userNotFound: return "userNotFound"
            }
        case .validation(let type):
            switch type {
            case .invalidEmail: return "invalidEmail"
            case .passwordTooShort: return "passwordTooShort"
            case .requiredFieldMissing: return "requiredFieldMissing"
            case .invalidFormat: return "invalidFormat"
            }
        case .persistence(let type):
            switch type {
            case .dataNotFound: return "dataNotFound"
            case .saveFailed: return "saveFailed"
            case .deleteFailed: return "deleteFailed"
            case .corruptedData: return "corruptedData"
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
        case .authentication(.sessionExpired):
            return "Session Expired"
        case .authentication:
            return "Authentication Error"
        case .validation:
            return "Invalid Input"
        case .persistence:
            return "Data Error"
        case .unknown:
            return "Error"
        }
    }
    
    @MainActor
    private func buildActions(for error: AppError) -> [ErrorPresentation.ErrorAction] {
        var actions: [ErrorPresentation.ErrorAction] = []
        
        // Add recovery action if available
        if let recoveryAction = error.suggestedRecoveryAction {
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
}

// MARK: - Default Logger Implementation

public struct ConsoleLogger: LoggerProtocol {
    public init() {}
    
    public func log(_ message: String, level: AppError.LogLevel, metadata: [String: Any]) {
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
