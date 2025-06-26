//
//  UserRepositoryProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol defining user repository operations
//

import Foundation

/// Protocol for user data persistence operations
public protocol UserRepositoryProtocol: Sendable {
    /// Creates a new user
    func create(_ user: User) async throws -> User
    
    /// Finds a user by ID
    func findById(_ id: UUID) async throws -> User?
    
    /// Finds a user by email
    func findByEmail(_ email: String) async throws -> User?
    
    /// Updates an existing user
    @MainActor
    func update(_ user: User) async throws -> User
    
    /// Deletes a user by ID
    func delete(_ id: UUID) async throws
    
    /// Retrieves all users
    func findAll() async throws -> [User]
}