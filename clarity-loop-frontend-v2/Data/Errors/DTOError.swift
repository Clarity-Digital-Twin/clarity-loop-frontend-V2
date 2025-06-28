//
//  DTOError.swift
//  ClarityData
//
//  DTO conversion errors
//

import Foundation

/// Errors that can occur during DTO conversions
public enum DTOError: LocalizedError {
    case invalidUUID(String)
    case invalidDate(String)
    case missingRequiredField(String)
    case invalidFieldValue(field: String, value: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidUUID(let uuid):
            return "Invalid UUID format: \(uuid)"
        case .invalidDate(let date):
            return "Invalid date format: \(date)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFieldValue(let field, let value):
            return "Invalid value '\(value)' for field: \(field)"
        }
    }
}
