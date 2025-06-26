//
//  RepositoryError.swift
//  clarity-loop-frontend-v2
//
//  Common repository errors
//

import Foundation

/// Errors that can occur in repository operations
public enum RepositoryError: LocalizedError {
    case saveFailed
    case fetchFailed
    case updateFailed
    case deleteFailed
    case notFound
    case invalidData
    case unauthorized
    case networkError(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .updateFailed:
            return "Failed to update data"
        case .deleteFailed:
            return "Failed to delete data"
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
}