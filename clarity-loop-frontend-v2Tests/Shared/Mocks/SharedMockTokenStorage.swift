//
//  SharedMockTokenStorage.swift
//  clarity-loop-frontend-v2Tests
//
//  Shared mock for TokenStorageProtocol used across all tests
//

import Foundation
import ClarityDomain
import ClarityData

/// Thread-safe mock token storage for testing
public actor SharedMockTokenStorage: TokenStorageProtocol {
    // MARK: - State
    
    private var storedToken: AuthToken?
    private var shouldThrowError = false
    private var errorToThrow: Error?
    
    // MARK: - Configuration
    
    public func setShouldThrowError(_ shouldThrow: Bool, error: Error? = nil) {
        self.shouldThrowError = shouldThrow
        self.errorToThrow = error ?? AppError.authenticationRequired
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
            throw errorToThrow ?? AppError.authenticationRequired
        }
        storedToken = token
    }
    
    public func getToken() async throws -> AuthToken? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken
    }
    
    public func getAccessToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken?.accessToken
    }
    
    public func getRefreshToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken?.refreshToken
    }
    
    public func clearToken() async throws {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        storedToken = nil
    }
}

/// Non-actor version for tests that don't need thread safety
public final class MockTokenStorage: TokenStorageProtocol {
    // MARK: - State
    
    public var storedToken: AuthToken?
    public var shouldThrowError = false
    public var errorToThrow: Error?
    
    public init() {}
    
    // MARK: - TokenStorageProtocol
    
    public func saveToken(_ token: AuthToken) async throws {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        storedToken = token
    }
    
    public func getToken() async throws -> AuthToken? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken
    }
    
    public func getAccessToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken?.accessToken
    }
    
    public func getRefreshToken() async throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        return storedToken?.refreshToken
    }
    
    public func clearToken() async throws {
        if shouldThrowError {
            throw errorToThrow ?? AppError.authenticationRequired
        }
        storedToken = nil
    }
}