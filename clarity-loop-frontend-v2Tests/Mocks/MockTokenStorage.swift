//
//  MockTokenStorage.swift
//  clarity-loop-frontend-v2Tests
//
//  Mock implementation of TokenStorageProtocol for testing
//

import Foundation
@testable import ClarityData
@testable import ClarityDomain

final class MockTokenStorage: TokenStorageProtocol {
    
    // MARK: - Mock State
    
    private var storedToken: AuthToken?
    var saveTokenCallCount = 0
    var loadTokenCallCount = 0
    var clearTokenCallCount = 0
    var shouldThrowError = false
    var customError: Error?
    
    // MARK: - TokenStorageProtocol
    
    func saveToken(_ token: AuthToken) async throws {
        saveTokenCallCount += 1
        
        if let error = customError {
            throw error
        }
        
        if shouldThrowError {
            throw NSError(domain: "MockTokenStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to store token"])
        }
        
        storedToken = token
    }
    
    func loadToken() async throws -> AuthToken? {
        loadTokenCallCount += 1
        
        if let error = customError {
            throw error
        }
        
        if shouldThrowError {
            throw NSError(domain: "MockTokenStorage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token not found"])
        }
        
        return storedToken
    }
    
    func clearToken() async throws {
        clearTokenCallCount += 1
        
        if let error = customError {
            throw error
        }
        
        if shouldThrowError {
            throw NSError(domain: "MockTokenStorage", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to delete token"])
        }
        
        storedToken = nil
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        storedToken = nil
        saveTokenCallCount = 0
        loadTokenCallCount = 0
        clearTokenCallCount = 0
        shouldThrowError = false
        customError = nil
    }
    
    func setStoredToken(_ token: AuthToken?) {
        storedToken = token
    }
    
    func getStoredToken() -> AuthToken? {
        return storedToken
    }
}
