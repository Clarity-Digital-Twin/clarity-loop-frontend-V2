//
//  PersistedUser.swift
//  clarity-loop-frontend-v2
//
//  SwiftData model for persisting User entities
//

import Foundation
import SwiftData

@Model
final class PersistedUser {
    @Attribute(.unique) var id: UUID
    var email: String
    var firstName: String
    var lastName: String
    var createdAt: Date
    var lastLoginAt: Date?
    var dateOfBirth: Date?
    var phoneNumber: String?
    
    init(
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