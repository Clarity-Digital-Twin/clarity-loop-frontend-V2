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
        self.errorToThrow = error ?? AppError.auth(.invalidCredentials)
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
            throw errorToThrow ?? AppError.auth(.invalidCredentials)
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
            throw errorToThrow ?? AppError.network(.serverError(500))
        }

        currentUser = nil
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return mockToken
    }

    public func getCurrentUser() async throws -> User? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return currentUser
    }
}

/// Mock authentication service for testing - Swift 6 compliant
public final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {

    // MARK: - State

    public var shouldThrowError = false
    public var errorToThrow: Error?
    public var loginCallCount = 0
    public var logoutCallCount = 0
    public var refreshTokenCallCount = 0
    public var getCurrentUserCallCount = 0
    public var mockUser: User?

    // MARK: - Test Configuration

    /// Configure the mock to throw specific errors
    public func setShouldThrowError(_ shouldThrow: Bool, error: Error? = nil) {
        self.shouldThrowError = shouldThrow
        self.errorToThrow = error ?? AppError.auth(.invalidCredentials)
    }

    // MARK: - AuthServiceProtocol Implementation

    public init() {
        self.mockUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
    }

    public func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.invalidCredentials)
        }

        return AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }

    public func logout() async throws {
        logoutCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.network(.serverError(500))
        }
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        refreshTokenCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return AuthToken(
            accessToken: "mock-refreshed-access-token",
            refreshToken: "mock-refreshed-refresh-token",
            expiresIn: 3600
        )
    }

    public func getCurrentUser() async throws -> User? {
        getCurrentUserCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return mockUser
    }
}

/// Mock extended auth service for testing
public final class MockExtendedAuthService: ExtendedAuthServiceProtocol, @unchecked Sendable {

    // MARK: - State

    public var shouldThrowError = false
    public var errorToThrow: Error?
    public var loginCallCount = 0
    public var signUpCallCount = 0
    public var verifyEmailCallCount = 0
    public var resendVerificationCallCount = 0
    public var resetPasswordCallCount = 0
    public var refreshTokenCallCount = 0
    public var logoutCallCount = 0
    public var getCurrentUserCallCount = 0
    public var mockUser: User?

    public init() {
        self.mockUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
    }

    public func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.invalidCredentials)
        }

        return AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }

    public func signUp(email: String, password: String, firstName: String, lastName: String) async throws -> User {
        signUpCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.validation(.invalidEmail)
        }

        return User(id: UUID(), email: email, firstName: firstName, lastName: lastName)
    }

    public func logout() async throws {
        logoutCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.network(.serverError(500))
        }
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        refreshTokenCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return AuthToken(
            accessToken: "mock-refreshed-access-token",
            refreshToken: "mock-refreshed-refresh-token",
            expiresIn: 3600
        )
    }

    public func getCurrentUser() async throws -> User? {
        getCurrentUserCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.auth(.sessionExpired)
        }

        return mockUser
    }

    public func verifyEmail(token: String) async throws {
        verifyEmailCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.validation(.missingRequiredField("token"))
        }
    }

    public func resendVerificationEmail(email: String) async throws {
        resendVerificationCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.network(.serverError(500))
        }
    }

    public func resetPassword(email: String) async throws {
        resetPasswordCallCount += 1

        if shouldThrowError {
            throw errorToThrow ?? AppError.validation(.invalidEmail)
        }
    }
}
