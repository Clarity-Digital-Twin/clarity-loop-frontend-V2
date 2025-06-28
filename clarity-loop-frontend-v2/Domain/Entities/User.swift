//
//  User.swift
//  clarity-loop-frontend-v2
//
//  User domain entity representing a user in the system
//

import Foundation

/// Domain entity representing a user in the CLARITY Pulse system
///
/// The User entity encapsulates all user-related data and business logic,
/// following Domain-Driven Design principles. It represents a registered
/// user who can track health metrics and interact with the system.
public struct User: Entity, Equatable, Hashable, Codable, Sendable {
    // MARK: - Entity Protocol Requirements
    
    public let id: UUID
    public let createdAt: Date
    public let updatedAt: Date
    
    // MARK: - User-Specific Properties
    
    /// User's email address (used for authentication)
    public let email: String
    
    /// User's first name
    public let firstName: String
    
    /// User's last name
    public let lastName: String
    
    /// Timestamp of the user's last login
    public let lastLoginAt: Date?
    
    /// User's date of birth (optional for profile completion)
    public let dateOfBirth: Date?
    
    /// User's phone number (optional for profile completion)
    public let phoneNumber: String?
    
    // MARK: - Computed Properties
    
    /// Full name combining first and last names
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
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        email: String,
        firstName: String,
        lastName: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastLoginAt: Date? = nil,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastLoginAt = lastLoginAt
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
    }
    
    // MARK: - Methods
    
    /// Creates a new User instance with updated last login timestamp
    public func withUpdatedLastLogin(_ date: Date = Date()) -> User {
        User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            createdAt: createdAt,
            updatedAt: date,
            lastLoginAt: date,
            dateOfBirth: dateOfBirth,
            phoneNumber: phoneNumber
        )
    }
    
    /// Creates a new User instance with updated profile information
    public func withUpdatedProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil
    ) -> User {
        User(
            id: id,
            email: email,
            firstName: firstName ?? self.firstName,
            lastName: lastName ?? self.lastName,
            createdAt: createdAt,
            updatedAt: Date(),
            lastLoginAt: lastLoginAt,
            dateOfBirth: dateOfBirth ?? self.dateOfBirth,
            phoneNumber: phoneNumber ?? self.phoneNumber
        )
    }
}

// MARK: - Test Support

#if DEBUG
public extension User {
    /// Creates a mock user for testing purposes
    static func mock(
        id: UUID = UUID(),
        email: String = "test@example.com",
        firstName: String = "Test",
        lastName: String = "User",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastLoginAt: Date? = nil,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil
    ) -> User {
        User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastLoginAt: lastLoginAt,
            dateOfBirth: dateOfBirth,
            phoneNumber: phoneNumber
        )
    }
}
#endif
