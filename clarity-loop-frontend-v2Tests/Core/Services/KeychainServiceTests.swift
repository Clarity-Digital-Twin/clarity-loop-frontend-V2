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
    
}