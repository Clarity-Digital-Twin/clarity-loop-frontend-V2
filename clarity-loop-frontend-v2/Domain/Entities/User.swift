//
//  User.swift
//  clarity-loop-frontend-v2
//
//  User domain entity representing a user in the system
//

import Foundation

/// Domain entity representing a user
@Observable
public final class User: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID
    public let email: String
    public let firstName: String
    public let lastName: String
    public let createdAt: Date
    public var lastLoginAt: Date?
    public var dateOfBirth: Date?
    public var phoneNumber: String?
    
    /// Computed property for full name
    public var fullName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? firstName : combined
    }
    
    /// Validates if the email format is correct
    public var hasValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    /// Checks if user profile is complete
    public var isProfileComplete: Bool {
        dateOfBirth != nil && phoneNumber != nil
    }
    
    public init(
        id: UUID = UUID(),
        email: String,
        firstName: String,
        lastName: String,
        createdAt: Date = Date(),
        lastLoginAt: Date? = nil,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
    }
    
    /// Updates the last login timestamp
    public func updateLastLogin(_ date: Date = Date()) {
        lastLoginAt = date
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}