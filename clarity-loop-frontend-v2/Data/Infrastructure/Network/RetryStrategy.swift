//
//  RetryStrategy.swift
//  clarity-loop-frontend-v2
//
//  Retry strategy for network requests
//

import Foundation

/// Protocol for retry strategies
public protocol RetryStrategy: Sendable {
    /// Determine if request should be retried
    func shouldRetry(
        for error: Error,
        attempt: Int
    ) -> RetryDecision
}

/// Decision on whether to retry
public enum RetryDecision: Sendable {
    case retry(after: TimeInterval)
    case doNotRetry
}

/// Default exponential backoff retry strategy
public struct ExponentialBackoffRetryStrategy: RetryStrategy {
    
    // MARK: - Properties
    
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let retryableStatusCodes: Set<Int>
    
    // MARK: - Initialization
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        retryableStatusCodes: Set<Int> = [500, 502, 503, 504]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }
    
    // MARK: - RetryStrategy
    
    public func shouldRetry(for error: Error, attempt: Int) -> RetryDecision {
        // Check attempt limit
        guard attempt < maxAttempts else {
            return .doNotRetry
        }
        
        // Check if error is retryable
        guard isRetryable(error) else {
            return .doNotRetry
        }
        
        // Calculate delay with exponential backoff
        let delay = calculateDelay(for: attempt)
        return .retry(after: delay)
    }
    
    // MARK: - Private Methods
    
    private func isRetryable(_ error: Error) -> Bool {
        // Check for rate limiting
        if case let NetworkError.rateLimited(retryAfter) = error {
            // Rate limited errors are retryable but use server-provided delay
            return retryAfter != nil
        }
        
        // Check URL errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        // Check network errors
        if let networkError = error as? NetworkError {
            // Check specific cases
            switch networkError {
            case .serverError(let statusCode, _):
                return retryableStatusCodes.contains(statusCode)
            case .offline, .timeout:
                return true
            case .rateLimited:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        // Handle rate limiting with server-provided delay
        let baseDelay = self.baseDelay
        
        // Exponential backoff with jitter
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0..<0.3) // 0-30% jitter
        let delayWithJitter = exponentialDelay * (1 + jitter)
        
        // Cap at max delay
        return min(delayWithJitter, maxDelay)
    }
}

/// No-retry strategy
public struct NoRetryStrategy: RetryStrategy {
    public init() {}
    
    public func shouldRetry(for error: Error, attempt: Int) -> RetryDecision {
        .doNotRetry
    }
}
