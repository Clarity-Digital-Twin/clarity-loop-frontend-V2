//
//  NetworkError.swift
//  clarity-loop-frontend-v2
//
//  Network error types
//

import Foundation

/// Network-specific errors
public enum NetworkError: LocalizedError, Equatable, Sendable {
    case offline
    case invalidURL
    case invalidResponse
    case decodingFailed(String)
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case cancelled
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let code, let message):
            return message ?? "Server error (code: \(code))"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Try again in \(Int(retryAfter)) seconds"
            }
            return "Rate limited. Please try again later"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request cancelled"
        case .unknown:
            return "Unknown error occurred"
        }
    }
    
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.offline, .offline),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.timeout, .timeout),
             (.cancelled, .cancelled),
             (.unknown, .unknown):
            return true
        case let (.decodingFailed(lhsMessage), .decodingFailed(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.serverError(lhsCode, lhsMessage), .serverError(rhsCode, rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case let (.rateLimited(lhsRetry), .rateLimited(rhsRetry)):
            return lhsRetry == rhsRetry
        default:
            return false
        }
    }
}
