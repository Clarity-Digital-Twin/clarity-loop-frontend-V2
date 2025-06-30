//
//  AppConfiguration.swift
//  clarity-loop-frontend-v2
//
//  Centralized configuration for different environments
//

import Foundation

/// Application configuration for different environments
public struct AppConfiguration: Sendable {
    
    // MARK: - Environment
    
    public enum Environment: String, Sendable {
        case development = "dev"
        case staging = "staging"
        case production = "prod"
        
        /// Current environment based on build configuration
        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }
    
    // MARK: - Properties
    
    public let environment: Environment
    public let apiBaseURL: URL
    public let apiTimeout: TimeInterval
    public let maxRetryAttempts: Int
    public let tokenExpirationBuffer: TimeInterval
    public let enableDebugLogging: Bool
    public let enableCrashReporting: Bool
    public let enableAnalytics: Bool
    
    // MARK: - Initialization
    
    private init(
        environment: Environment,
        apiBaseURL: URL,
        apiTimeout: TimeInterval = 30,
        maxRetryAttempts: Int = 3,
        tokenExpirationBuffer: TimeInterval = 30,
        enableDebugLogging: Bool = false,
        enableCrashReporting: Bool = true,
        enableAnalytics: Bool = true
    ) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.apiTimeout = apiTimeout
        self.maxRetryAttempts = maxRetryAttempts
        self.tokenExpirationBuffer = tokenExpirationBuffer
        self.enableDebugLogging = enableDebugLogging
        self.enableCrashReporting = enableCrashReporting
        self.enableAnalytics = enableAnalytics
    }
    
    // MARK: - Factory Methods
    
    /// Current configuration based on environment
    public static var current: AppConfiguration {
        switch Environment.current {
        case .development:
            return .development
        case .staging:
            return .staging
        case .production:
            return .production
        }
    }
    
    /// Development configuration
    public static let development = AppConfiguration(
        environment: .development,
        apiBaseURL: URL(string: "https://dev.clarity.novamindnyc.com")!,
        apiTimeout: 60,
        maxRetryAttempts: 5,
        enableDebugLogging: true,
        enableCrashReporting: false,
        enableAnalytics: false
    )
    
    /// Staging configuration
    public static let staging = AppConfiguration(
        environment: .staging,
        apiBaseURL: URL(string: "https://staging.clarity.novamindnyc.com")!,
        apiTimeout: 45,
        maxRetryAttempts: 3,
        enableDebugLogging: false,
        enableCrashReporting: true,
        enableAnalytics: true
    )
    
    /// Production configuration
    public static let production = AppConfiguration(
        environment: .production,
        apiBaseURL: URL(string: "https://clarity.novamindnyc.com")!,
        apiTimeout: 30,
        maxRetryAttempts: 3,
        enableDebugLogging: false,
        enableCrashReporting: true,
        enableAnalytics: true
    )
    
    // MARK: - Environment Variables Override
    
    /// Load configuration from environment variables (for CI/CD)
    public static func fromEnvironment() -> AppConfiguration? {
        guard let apiURLString = ProcessInfo.processInfo.environment["CLARITY_API_URL"],
              let apiURL = URL(string: apiURLString) else {
            return nil
        }
        
        let environment = ProcessInfo.processInfo.environment["CLARITY_ENV"]
            .flatMap(Environment.init(rawValue:)) ?? .production
        
        let apiTimeout = ProcessInfo.processInfo.environment["CLARITY_API_TIMEOUT"]
            .flatMap(Double.init) ?? 30
        
        let maxRetries = ProcessInfo.processInfo.environment["CLARITY_MAX_RETRIES"]
            .flatMap(Int.init) ?? 3
        
        return AppConfiguration(
            environment: environment,
            apiBaseURL: apiURL,
            apiTimeout: apiTimeout,
            maxRetryAttempts: maxRetries,
            enableDebugLogging: environment == .development,
            enableCrashReporting: environment != .development,
            enableAnalytics: environment != .development
        )
    }
}

// MARK: - Info.plist Keys

extension AppConfiguration {
    
    /// Keys for storing configuration in Info.plist
    private enum InfoPlistKey {
        static let apiURL = "ClarityAPIURL"
        static let environment = "ClarityEnvironment"
    }
    
    /// Load configuration from Info.plist
    public static func fromInfoPlist() -> AppConfiguration? {
        guard let info = Bundle.main.infoDictionary,
              let apiURLString = info[InfoPlistKey.apiURL] as? String,
              let apiURL = URL(string: apiURLString) else {
            return nil
        }
        
        let environmentString = info[InfoPlistKey.environment] as? String ?? "prod"
        let environment = Environment(rawValue: environmentString) ?? .production
        
        return AppConfiguration(
            environment: environment,
            apiBaseURL: apiURL,
            enableDebugLogging: environment == .development,
            enableCrashReporting: environment != .development,
            enableAnalytics: environment != .development
        )
    }
}

// MARK: - Configuration Loading Priority

extension AppConfiguration {
    
    /// Load configuration with fallback priority:
    /// 1. Environment variables (highest priority)
    /// 2. Info.plist
    /// 3. Compiled defaults (lowest priority)
    public static func load() -> AppConfiguration {
        // First try environment variables (for CI/CD and testing)
        if let envConfig = fromEnvironment() {
            return envConfig
        }
        
        // Then try Info.plist (for build-time configuration)
        if let plistConfig = fromInfoPlist() {
            return plistConfig
        }
        
        // Finally use compiled defaults
        return current
    }
}
