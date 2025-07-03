//
//  SharedMockTokenStorage.swift
//  clarity-loop-frontend-v2Tests
//
//  Shared mock for TokenStorageProtocol used across all tests
//

import Foundation
import ClarityDomain
import ClarityCore

/// Mock token storage for testing - Swift 6 compliant
public final class MockTokenStorage: TokenStorageProtocol, @unchecked Sendable {

    // MARK: - State

    public var storedToken: AuthToken?
    public var shouldThrowError = false
    public var errorToThrow: Error?

    public init() {}

    // MARK: - Configuration

    public func setShouldThrowError(_ shouldThrow: Bool, error: Error? = nil) {
        self.shouldThrowError = shouldThrow
        self.errorToThrow = error ?? AppError.persistence(.saveFailure)
    }

    public func setStoredToken(_ token: AuthToken?) {
        self.storedToken = token
    }

    public func reset() {
        storedToken = nil
        shouldThrowError = false
        errorToThrow = nil
    }

    // MARK: - TokenStorageProtocol

    public func saveToken(_ token: AuthToken) async throws {
        if shouldThrowError {
            throw errorToThrow ?? AppError.persistence(.saveFailure)
        }
        storedToken = token
    }

    public func getToken() async throws -> AuthToken? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.persistence(.fetchFailure)
        }
        return storedToken
    }

    public func getAccessToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.persistence(.fetchFailure)
        }
        return storedToken?.accessToken
    }

    public func getRefreshToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.persistence(.fetchFailure)
        }
        return storedToken?.refreshToken
    }

    public func clearToken() async throws {
        if shouldThrowError {
            throw errorToThrow ?? AppError.persistence(.deleteFailure)
        }
        storedToken = nil
    }
}
