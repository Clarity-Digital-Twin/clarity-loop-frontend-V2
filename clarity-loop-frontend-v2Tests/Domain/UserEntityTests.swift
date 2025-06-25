//
//  UserEntityTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for User domain entity following TDD principles
//

import XCTest
@testable import clarity_loop_frontend_v2

final class UserEntityTests: XCTestCase {
    
    // MARK: - Test User Creation
    
    func test_whenCreatingUser_withValidData_shouldInitializeCorrectly() {
        // Given
        let id = UUID()
        let email = "test@example.com"
        let firstName = "John"
        let lastName = "Doe"
        
        // When
        let user = User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
        
        // Then
        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.firstName, firstName)
        XCTAssertEqual(user.lastName, lastName)
        XCTAssertNotNil(user.createdAt)
        XCTAssertNil(user.lastLoginAt)
    }
    
    // MARK: - Test Full Name
    
    func test_whenGettingFullName_shouldCombineFirstAndLastName() {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Jane",
            lastName: "Smith"
        )
        
        // When
        let fullName = user.fullName
        
        // Then
        XCTAssertEqual(fullName, "Jane Smith")
    }
    
    func test_whenGettingFullName_withEmptyLastName_shouldReturnFirstNameOnly() {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Jane",
            lastName: ""
        )
        
        // When
        let fullName = user.fullName
        
        // Then
        XCTAssertEqual(fullName, "Jane")
    }
    
    // MARK: - Test Email Validation
    
    func test_whenValidatingEmail_withValidFormat_shouldReturnTrue() {
        // Given
        let validEmails = [
            "user@example.com",
            "test.user@company.co.uk",
            "user+tag@domain.org"
        ]
        
        // When & Then
        for email in validEmails {
            let user = User(
                id: UUID(),
                email: email,
                firstName: "Test",
                lastName: "User"
            )
            XCTAssertTrue(user.hasValidEmail, "Email '\(email)' should be valid")
        }
    }
    
    func test_whenValidatingEmail_withInvalidFormat_shouldReturnFalse() {
        // Given
        let invalidEmails = [
            "notanemail",
            "@example.com",
            "user@",
            "user @example.com",
            ""
        ]
        
        // When & Then
        for email in invalidEmails {
            let user = User(
                id: UUID(),
                email: email,
                firstName: "Test",
                lastName: "User"
            )
            XCTAssertFalse(user.hasValidEmail, "Email '\(email)' should be invalid")
        }
    }
    
    // MARK: - Test Profile Completion
    
    func test_whenCheckingProfileCompletion_withAllFields_shouldReturnTrue() {
        // Given
        let user = User(
            id: UUID(),
            email: "user@example.com",
            firstName: "John",
            lastName: "Doe",
            dateOfBirth: Date(),
            phoneNumber: "+1234567890"
        )
        
        // When
        let isComplete = user.isProfileComplete
        
        // Then
        XCTAssertTrue(isComplete)
    }
    
    func test_whenCheckingProfileCompletion_withMissingFields_shouldReturnFalse() {
        // Given
        let user = User(
            id: UUID(),
            email: "user@example.com",
            firstName: "John",
            lastName: "Doe"
            // Missing dateOfBirth and phoneNumber
        )
        
        // When
        let isComplete = user.isProfileComplete
        
        // Then
        XCTAssertFalse(isComplete)
    }
    
    // MARK: - Test Update Methods
    
    func test_whenUpdatingLastLogin_shouldUpdateTimestamp() {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        XCTAssertNil(user.lastLoginAt)
        
        // When
        user.updateLastLogin()
        
        // Then
        XCTAssertNotNil(user.lastLoginAt)
        XCTAssertTrue(user.lastLoginAt! <= Date())
    }
    
    // MARK: - Test Equatable
    
    func test_whenComparingUsers_withSameId_shouldBeEqual() {
        // Given
        let id = UUID()
        let user1 = User(id: id, email: "user1@example.com", firstName: "User", lastName: "One")
        let user2 = User(id: id, email: "user2@example.com", firstName: "User", lastName: "Two")
        
        // When & Then
        XCTAssertEqual(user1, user2, "Users with same ID should be equal")
    }
    
    func test_whenComparingUsers_withDifferentId_shouldNotBeEqual() {
        // Given
        let user1 = User(id: UUID(), email: "user@example.com", firstName: "User", lastName: "Name")
        let user2 = User(id: UUID(), email: "user@example.com", firstName: "User", lastName: "Name")
        
        // When & Then
        XCTAssertNotEqual(user1, user2, "Users with different IDs should not be equal")
    }
}