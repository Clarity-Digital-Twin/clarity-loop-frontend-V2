//
//  RepositoryError.swift
//  clarity-loop-frontend-v2
//
//  Common repository errors
//

import Foundation

/// Errors that can occur in repository operations
public enum RepositoryError: LocalizedError, Equatable {
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case notFound
    case invalidData
    case unauthorized
    case networkError(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete: \(reason)"
        case .notFound:
            return "Requested data not found"
        case .invalidData:
            return "Invalid data format"
        case .unauthorized:
            return "Unauthorized access"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    // Conformance to Equatable
    public static func == (lhs: RepositoryError, rhs: RepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.saveFailed(let l), .saveFailed(let r)):
            return l == r
        case (.fetchFailed(let l), .fetchFailed(let r)):
            return l == r
        case (.updateFailed(let l), .updateFailed(let r)):
            return l == r
        case (.deleteFailed(let l), .deleteFailed(let r)):
            return l == r
        case (.notFound, .notFound),
             (.invalidData, .invalidData),
             (.unauthorized, .unauthorized):
            return true
        case (.networkError(let l), .networkError(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}