//
//  User.swift
//  clarity-loop-frontend-v2
//
//  User domain entity representing a user in the system
//

import Foundation

/// Domain entity representing a user
@Observable
final class User: Identifiable, Equatable {
    let id: UUID
    let email: String
    let firstName: String
    let lastName: String
    let createdAt: Date
    var lastLoginAt: Date?
    var dateOfBirth: Date?
    var phoneNumber: String?
    
    /// Computed property for full name
    var fullName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? firstName : combined
    }
    
    /// Validates if the email format is correct
    var hasValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    /// Checks if user profile is complete
    var isProfileComplete: Bool {
        dateOfBirth != nil && phoneNumber != nil
    }
    
    init(
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
    func updateLastLogin() {
        lastLoginAt = Date()
    }
    
    // MARK: - Equatable
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}