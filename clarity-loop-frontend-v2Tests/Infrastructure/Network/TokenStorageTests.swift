//
//  TokenStorageTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for Token Storage
//

import XCTest
@testable import ClarityData
@testable import ClarityDomain
@testable import ClarityCore

final class TokenStorageTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: TokenStorageProtocol!
    private var mockKeychain: MockKeychainService!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
        sut = TokenStorage(keychain: mockKeychain)
    }
    
    override func tearDown() {
        sut = nil
        mockKeychain = nil
        super.tearDown()
    }
    
    // MARK: - Save Token Tests
    
    func test_saveToken_shouldStoreInKeychain() async throws {
        // Given
        let token = AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresIn: 3600
        )
        
        // When
        try await sut.saveToken(token)
        
        // Then
        XCTAssertTrue(mockKeychain.saveCalled)
        XCTAssertEqual(mockKeychain.savedValues["auth.accessToken"], "test-access-token")
        XCTAssertEqual(mockKeychain.savedValues["auth.refreshToken"], "test-refresh-token")
        XCTAssertNotNil(mockKeychain.savedValues["auth.expiresAt"])
    }
    
    func test_saveToken_whenKeychainFails_shouldThrowError() async {
        // Given
        let token = AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresIn: 3600
        )
        mockKeychain.shouldThrowError = true
        
        // When/Then
        do {
            try await sut.saveToken(token)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    // MARK: - Get Token Tests
    
    func test_getToken_whenTokenExists_shouldReturnToken() async throws {
        // Given
        let expiresAt = Date().addingTimeInterval(3600)
        mockKeychain.savedValues = [
            "auth.accessToken": "stored-access-token",
            "auth.refreshToken": "stored-refresh-token",
            "auth.expiresAt": expiresAt.timeIntervalSince1970.description
        ]
        
        // When
        let token = try await sut.getToken()
        
        // Then
        XCTAssertNotNil(token)
        XCTAssertEqual(token?.accessToken, "stored-access-token")
        XCTAssertEqual(token?.refreshToken, "stored-refresh-token")
    }
    
    func test_getToken_whenTokenNotExists_shouldReturnNil() async throws {
        // Given
        mockKeychain.savedValues = [:]
        
        // When
        let token = try await sut.getToken()
        
        // Then
        XCTAssertNil(token)
    }
    
    func test_getToken_whenTokenExpired_shouldReturnNil() async throws {
        // Given
        let expiredDate = Date().addingTimeInterval(-3600) // 1 hour ago
        mockKeychain.savedValues = [
            "auth.accessToken": "expired-access-token",
            "auth.refreshToken": "expired-refresh-token",
            "auth.expiresAt": expiredDate.timeIntervalSince1970.description
        ]
        
        // When
        let token = try await sut.getToken()
        
        // Then
        XCTAssertNil(token)
    }
    
    // MARK: - Clear Token Tests
    
    func test_clearToken_shouldRemoveFromKeychain() async throws {
        // Given
        mockKeychain.savedValues = [
            "auth.accessToken": "stored-access-token",
            "auth.refreshToken": "stored-refresh-token",
            "auth.expiresAt": "12345"
        ]
        
        // When
        try await sut.clearToken()
        
        // Then
        XCTAssertTrue(mockKeychain.deleteCalled)
        XCTAssertEqual(mockKeychain.deletedKeys.count, 3)
        XCTAssertTrue(mockKeychain.deletedKeys.contains("auth.accessToken"))
        XCTAssertTrue(mockKeychain.deletedKeys.contains("auth.refreshToken"))
        XCTAssertTrue(mockKeychain.deletedKeys.contains("auth.expiresAt"))
    }
    
    // MARK: - Get Access Token Tests
    
    func test_getAccessToken_whenTokenValid_shouldReturnAccessToken() async throws {
        // Given
        let expiresAt = Date().addingTimeInterval(3600)
        mockKeychain.savedValues = [
            "auth.accessToken": "valid-access-token",
            "auth.refreshToken": "valid-refresh-token",
            "auth.expiresAt": expiresAt.timeIntervalSince1970.description
        ]
        
        // When
        let accessToken = try await sut.getAccessToken()
        
        // Then
        XCTAssertEqual(accessToken, "valid-access-token")
    }
    
    func test_getAccessToken_whenTokenExpired_shouldReturnNil() async throws {
        // Given
        let expiredDate = Date().addingTimeInterval(-3600)
        mockKeychain.savedValues = [
            "auth.accessToken": "expired-access-token",
            "auth.refreshToken": "expired-refresh-token",
            "auth.expiresAt": expiredDate.timeIntervalSince1970.description
        ]
        
        // When
        let accessToken = try await sut.getAccessToken()
        
        // Then
        XCTAssertNil(accessToken)
    }
}

// MARK: - Mock Classes

private final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    var saveCalled = false
    var retrieveCalled = false
    var deleteCalled = false
    var shouldThrowError = false
    var savedValues: [String: String] = [:]
    var deletedKeys: [String] = []
    
    func save(_ value: String, forKey key: String) throws {
        saveCalled = true
        if shouldThrowError {
            throw KeychainError.unhandledError(status: -1)
        }
        savedValues[key] = value
    }
    
    func retrieve(_ key: String) throws -> String {
        retrieveCalled = true
        if shouldThrowError {
            throw KeychainError.itemNotFound
        }
        guard let value = savedValues[key] else {
            throw KeychainError.itemNotFound
        }
        return value
    }
    
    func delete(_ key: String) throws {
        deleteCalled = true
        if shouldThrowError {
            throw KeychainError.unhandledError(status: -1)
        }
        deletedKeys.append(key)
        savedValues.removeValue(forKey: key)
    }
}