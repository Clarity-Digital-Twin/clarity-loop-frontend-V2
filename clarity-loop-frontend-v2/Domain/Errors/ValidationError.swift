//
//  ValidationError.swift
//  clarity-loop-frontend-v2
//
//  Validation errors for domain logic
//

import Foundation

/// Errors that occur during validation
public enum ValidationError: LocalizedError, Equatable {
    case invalidValue(field: String, reason: String)
    case missingRequiredField(field: String)
    case outOfRange(field: String, min: Double?, max: Double?)
    case invalidFormat(field: String)
    case duplicateEntry(field: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidValue(let field, let reason):
            return "\(field) is invalid: \(reason)"
        case .missingRequiredField(let field):
            return "\(field) is required"
        case .outOfRange(let field, let min, let max):
            if let min = min, let max = max {
                return "\(field) must be between \(min) and \(max)"
            } else if let min = min {
                return "\(field) must be at least \(min)"
            } else if let max = max {
                return "\(field) must be at most \(max)"
            } else {
                return "\(field) is out of range"
            }
        case .invalidFormat(let field):
            return "\(field) has invalid format"
        case .duplicateEntry(let field):
            return "\(field) already exists"
        }
    }
}
