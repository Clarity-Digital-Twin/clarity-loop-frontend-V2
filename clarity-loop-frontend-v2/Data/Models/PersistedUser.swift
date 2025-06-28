//
//  PersistedUser.swift
//  clarity-loop-frontend-v2
//
//  SwiftData model for persisting User entities
//

import Foundation
import SwiftData

@Model
public final class PersistedUser {
    @Attribute(.unique) public var id: UUID
    public var email: String
    public var firstName: String
    public var lastName: String
    public var createdAt: Date
    public var lastLoginAt: Date?
    public var dateOfBirth: Date?
    public var phoneNumber: String?
    
    public init(
        id: UUID,
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
}
