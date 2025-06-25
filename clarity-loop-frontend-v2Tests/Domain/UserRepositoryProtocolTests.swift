//
//  UserRepositoryProtocolTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for UserRepository protocol definition
//

import XCTest
@testable import clarity_loop_frontend_v2

final class UserRepositoryProtocolTests: XCTestCase {
    
    // MARK: - Mock Implementation
    
    private class MockUserRepository: UserRepositoryProtocol {
        var users: [UUID: User] = [:]
        var shouldThrowError = false
        
        func create(_ user: User) async throws -> User {
            if shouldThrowError {
                throw RepositoryError.saveFailed
            }
            users[user.id] = user
            return user
        }
        
        func findById(_ id: UUID) async throws -> User? {
            if shouldThrowError {
                throw RepositoryError.fetchFailed
            }
            return users[id]
        }
        
        func findByEmail(_ email: String) async throws -> User? {
            if shouldThrowError {
                throw RepositoryError.fetchFailed
            }
            return users.values.first { $0.email == email }
        }
        
        func update(_ user: User) async throws -> User {
            if shouldThrowError {
                throw RepositoryError.updateFailed
            }
            guard users[user.id] != nil else {
                throw RepositoryError.notFound
            }
            users[user.id] = user
            return user
        }
        
        func delete(_ id: UUID) async throws {
            if shouldThrowError {
                throw RepositoryError.deleteFailed
            }
            users.removeValue(forKey: id)
        }
        
        func findAll() async throws -> [User] {
            if shouldThrowError {
                throw RepositoryError.fetchFailed
            }
            return Array(users.values)
        }
    }
    
    // MARK: - Tests
    
    func test_whenCreatingUser_shouldStoreAndReturnUser() async throws {
        // Given
        let repository = MockUserRepository()
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        // When
        let savedUser = try await repository.create(user)
        
        // Then
        XCTAssertEqual(savedUser.id, user.id)
        XCTAssertEqual(repository.users.count, 1)
    }
    
    func test_whenFindingById_withExistingUser_shouldReturnUser() async throws {
        // Given
        let repository = MockUserRepository()
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        _ = try await repository.create(user)
        
        // When
        let foundUser = try await repository.findById(user.id)
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.id, user.id)
    }
    
    func test_whenFindingByEmail_withExistingUser_shouldReturnUser() async throws {
        // Given
        let repository = MockUserRepository()
        let email = "unique@example.com"
        let user = User(
            id: UUID(),
            email: email,
            firstName: "Test",
            lastName: "User"
        )
        _ = try await repository.create(user)
        
        // When
        let foundUser = try await repository.findByEmail(email)
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.email, email)
    }
    
    func test_whenUpdatingUser_shouldModifyExistingUser() async throws {
        // Given
        let repository = MockUserRepository()
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Original",
            lastName: "User"
        )
        _ = try await repository.create(user)
        
        // When
        user.updateLastLogin()
        let updatedUser = try await repository.update(user)
        
        // Then
        XCTAssertNotNil(updatedUser.lastLoginAt)
        XCTAssertEqual(repository.users[user.id]?.lastLoginAt, user.lastLoginAt)
    }
    
    func test_whenDeletingUser_shouldRemoveFromRepository() async throws {
        // Given
        let repository = MockUserRepository()
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        _ = try await repository.create(user)
        XCTAssertEqual(repository.users.count, 1)
        
        // When
        try await repository.delete(user.id)
        
        // Then
        XCTAssertEqual(repository.users.count, 0)
        let foundUser = try await repository.findById(user.id)
        XCTAssertNil(foundUser)
    }
    
    func test_whenFindingAll_shouldReturnAllUsers() async throws {
        // Given
        let repository = MockUserRepository()
        let users = (1...3).map { index in
            User(
                id: UUID(),
                email: "user\(index)@example.com",
                firstName: "User",
                lastName: "\(index)"
            )
        }
        
        for user in users {
            _ = try await repository.create(user)
        }
        
        // When
        let allUsers = try await repository.findAll()
        
        // Then
        XCTAssertEqual(allUsers.count, 3)
    }
    
    func test_whenRepositoryFails_shouldThrowAppropriateError() async {
        // Given
        let repository = MockUserRepository()
        repository.shouldThrowError = true
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        // When & Then
        do {
            _ = try await repository.create(user)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
}