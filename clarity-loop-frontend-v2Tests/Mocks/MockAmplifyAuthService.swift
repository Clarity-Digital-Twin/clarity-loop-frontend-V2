//
//  MockAmplifyAuthService.swift
//  clarity-loop-frontend-v2Tests
//
//  Lightweight mock for Amplify Auth to prevent test timeouts
//

import Foundation
@testable import ClarityDomain
@testable import ClarityData

/// Mock implementation of AuthServiceProtocol for testing
/// This prevents real Amplify calls that cause test timeouts
final class MockAmplifyAuthService: AuthServiceProtocol {
    
    // MARK: - Mock State
    
    var shouldSucceed = true
    var mockUser: User?
    var mockToken: AuthToken?
    var loginCallCount = 0
    var logoutCallCount = 0
    var refreshTokenCallCount = 0
    var lastLoginEmail: String?
    var lastLoginPassword: String?
    var lastRefreshToken: String?
    
    // MARK: - Customizable Responses
    
    var loginDelay: TimeInterval = 0
    var customLoginError: Error?
    var customLogoutError: Error?
    var customRefreshError: Error?
    
    init() {
        // Default mock data
        self.mockUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        self.mockToken = AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    // MARK: - AuthServiceProtocol
    
    func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1
        lastLoginEmail = email
        lastLoginPassword = password
        
        // Simulate network delay if configured
        if loginDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(loginDelay * 1_000_000_000))
        }
        
        // Throw custom error if configured
        if let error = customLoginError {
            throw error
        }
        
        // Check success flag
        guard shouldSucceed else {
            throw AuthError.invalidCredentials
        }
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        return mockToken ?? AuthToken(
            accessToken: "default-mock-token",
            refreshToken: "default-refresh-token",
            expiresIn: 3600
        )
    }
    
    func logout() async throws {
        logoutCallCount += 1
        
        if let error = customLogoutError {
            throw error
        }
        
        guard shouldSucceed else {
            throw AuthError.unknown("Logout failed")
        }
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        guard shouldSucceed else {
            return nil
        }
        
        return mockUser
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        refreshTokenCallCount += 1
        lastRefreshToken = refreshToken
        
        if let error = customRefreshError {
            throw error
        }
        
        guard shouldSucceed else {
            throw AuthError.tokenExpired
        }
        
        return AuthToken(
            accessToken: "refreshed-mock-token",
            refreshToken: "refreshed-refresh-token",
            expiresIn: 3600
        )
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        shouldSucceed = true
        loginCallCount = 0
        logoutCallCount = 0
        refreshTokenCallCount = 0
        lastLoginEmail = nil
        lastLoginPassword = nil
        lastRefreshToken = nil
        loginDelay = 0
        customLoginError = nil
        customLogoutError = nil
        customRefreshError = nil
    }
}