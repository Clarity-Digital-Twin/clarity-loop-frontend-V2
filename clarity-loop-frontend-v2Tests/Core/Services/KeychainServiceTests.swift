//
//  KeychainServiceTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for Keychain integration
//

import XCTest
@testable import ClarityCore

final class KeychainServiceTests: XCTestCase {
    
    private var sut: KeychainServiceProtocol!
    private let testKey = "test.token"
    private let testValue = "secret-token-123"
    
    override func setUp() {
        super.setUp()
        sut = KeychainService()
        // Clean up any existing test data
        try? sut.delete(testKey)
    }
    
    override func tearDown() {
        try? sut.delete(testKey)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func test_save_shouldStoreValueSecurely() async throws {
        // When
        try sut.save(testValue, forKey: testKey)
        
        // Then
        let retrieved = try sut.retrieve(testKey)
        XCTAssertEqual(retrieved, testValue)
    }
    
    func test_save_withExistingKey_shouldUpdateValue() async throws {
        // Given
        try sut.save("old-value", forKey: testKey)
        
        // When
        try sut.save(testValue, forKey: testKey)
        
        // Then
        let retrieved = try sut.retrieve(testKey)
        XCTAssertEqual(retrieved, testValue)
    }
    
    // MARK: - Retrieve Tests
    
    func test_retrieve_withNonExistentKey_shouldThrowError() {
        // When/Then
        XCTAssertThrowsError(try sut.retrieve("non.existent.key")) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }
    
    // MARK: - Delete Tests
    
    func test_delete_shouldRemoveValue() async throws {
        // Given
        try sut.save(testValue, forKey: testKey)
        
        // When
        try sut.delete(testKey)
        
        // Then
        XCTAssertThrowsError(try sut.retrieve(testKey))
    }
    
    func test_delete_withNonExistentKey_shouldNotThrow() {
        // When/Then
        XCTAssertNoThrow(try sut.delete("non.existent.key"))
    }
    
    // MARK: - Token Storage Tests
    
    func test_saveAuthToken_shouldStoreTokenSecurely() async throws {
        // Given
        let token = AuthToken(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresIn: 3600
        )
        
        // When
        try sut.saveAuthToken(token)
        
        // Then
        let retrieved = try sut.retrieveAuthToken()
        XCTAssertEqual(retrieved.accessToken, token.accessToken)
        XCTAssertEqual(retrieved.refreshToken, token.refreshToken)
        XCTAssertEqual(retrieved.expiresIn, token.expiresIn)
    }
    
    func test_deleteAuthToken_shouldRemoveAllTokenData() async throws {
        // Given
        let token = AuthToken(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresIn: 3600
        )
        try sut.saveAuthToken(token)
        
        // When
        try sut.deleteAuthToken()
        
        // Then
        XCTAssertThrowsError(try sut.retrieveAuthToken())
    }
}