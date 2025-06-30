//
//  SharedMockAuthService.swift
//  clarity-loop-frontend-v2Tests
//
//  Shared mock for AuthServiceProtocol used across all tests
//

import Foundation
import ClarityDomain
import ClarityCore

/// Thread-safe mock authentication service for testing
public actor SharedMockAuthService: AuthServiceProtocol {
    // MARK: - State
    
    private var shouldThrowError = false
    private var errorToThrow: Error?
    private var loginCallCount = 0
    private var logoutCallCount = 0
    private var currentUser: User?
    private var mockToken = AuthToken(
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        expiresIn: 3600
    )
    
    // MARK: - Configuration
    
    public func setShouldThrowError(_ shouldThrow: Bool, error: Error? = nil) {
        self.shouldThrowError = shouldThrow
        self.errorToThrow = error ?? AppError.invalidCredentials
    }
    
    public func setMockToken(_ token: AuthToken) {
        self.mockToken = token
    }
    
    public func setCurrentUser(_ user: User?) {
        self.currentUser = user
    }
    
    public func getLoginCallCount() -> Int {
        return loginCallCount
    }
    
    public func getLogoutCallCount() -> Int {
        return logoutCallCount
    }
    
    public func reset() {
        shouldThrowError = false
        errorToThrow = nil
        loginCallCount = 0
        logoutCallCount = 0
        currentUser = nil
        mockToken = AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    // MARK: - AuthServiceProtocol
    
    public func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow ?? AppError.invalidCredentials
        }
        
        // Set a default user if none exists
        if currentUser == nil {
            currentUser = User(
                id: UUID(),
                email: email,
                firstName: "Test",
                lastName: "User",
                dateOfBirth: Date(timeIntervalSinceNow: -365 * 25 * 24 * 60 * 60) // 25 years ago
            )
        }
        
        return mockToken
    }
    
    public func logout() async throws {
        logoutCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow ?? AppError.networkError("Logout failed")
        }
        
        currentUser = nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        
        return mockToken
    }
    
    public func getCurrentUser() async throws -> User? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        
        return currentUser
    }
}

/// Non-actor version for tests that don't need thread safety
public final class MockAuthService: AuthServiceProtocol {
    // MARK: - State
    
    public var shouldThrowError = false
    public var errorToThrow: Error?
    public var loginCallCount = 0
    public var logoutCallCount = 0
    public var currentUser: User?
    public var mockToken = AuthToken(
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        expiresIn: 3600
    )
    
    public init() {}
    
    // MARK: - AuthServiceProtocol
    
    public func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow ?? AppError.invalidCredentials
        }
        
        // Set a default user if none exists
        if currentUser == nil {
            currentUser = User(
                id: UUID(),
                email: email,
                firstName: "Test",
                lastName: "User",
                dateOfBirth: Date(timeIntervalSinceNow: -365 * 25 * 24 * 60 * 60) // 25 years ago
            )
        }
        
        return mockToken
    }
    
    public func logout() async throws {
        logoutCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow ?? AppError.networkError("Logout failed")
        }
        
        currentUser = nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        
        return mockToken
    }
    
    public func getCurrentUser() async throws -> User? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        
        return currentUser
    }
}