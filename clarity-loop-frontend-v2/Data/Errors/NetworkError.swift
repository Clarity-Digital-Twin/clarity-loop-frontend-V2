//
//  NetworkError.swift
//  clarity-loop-frontend-v2
//
//  Network-related errors
//

import Foundation

/// Network-related errors
public enum NetworkError: LocalizedError, Equatable {
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case noConnection
    case decodingFailed(String)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error occurred"
        case .noConnection:
            return "No internet connection"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
    
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.serverError, .serverError),
             (.noConnection, .noConnection),
             (.unknown, .unknown):
            return true
        case (.decodingFailed(let lhsMsg), .decodingFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}