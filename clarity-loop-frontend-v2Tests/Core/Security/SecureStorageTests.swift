//
//  SecureStorageTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for SecureStorage implementation
//

import XCTest
import CryptoKit
@testable import ClarityCore

final class SecureStorageTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: SecureStorage!
    private var mockKeychain: MockSecureKeychainService!
    private var mockBiometric: MockBiometricService!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockSecureKeychainService()
        mockBiometric = MockBiometricService()
        sut = SecureStorage(
            keychainService: mockKeychain,
            biometricService: mockBiometric
        )
    }
    
    override func tearDown() {
        sut = nil
        mockKeychain = nil
        mockBiometric = nil
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func test_saveData_shouldEncryptAndStoreInKeychain() async throws {
        // Given
        let testData = "Secret health data".data(using: .utf8)!
        let key = "test.health.data"
        
        // When
        try await sut.save(testData, forKey: key, requiresBiometric: false)
        
        // Then
        XCTAssertEqual(mockKeychain.storedItems.count, 1)
        let storedItem = mockKeychain.storedItems[key]
        XCTAssertNotNil(storedItem)
        
        // Verify data was encrypted (not same as original)
        XCTAssertNotEqual(storedItem?.data, testData)
        
        // Verify proper attributes set
        XCTAssertEqual(storedItem?.accessible, .whenUnlockedThisDeviceOnly)
        XCTAssertFalse(storedItem?.requiresBiometric ?? true)
    }
    
    func test_saveData_withBiometric_shouldRequireAuthentication() async throws {
        // Given
        let testData = "Sensitive data".data(using: .utf8)!
        let key = "test.sensitive"
        
        // When
        try await sut.save(testData, forKey: key, requiresBiometric: true)
        
        // Then
        let storedItem = mockKeychain.storedItems[key]
        XCTAssertTrue(storedItem?.requiresBiometric ?? false)
        XCTAssertEqual(storedItem?.accessible, .whenPasscodeSetThisDeviceOnly)
    }
    
    func test_saveCodable_shouldEncodeAndEncrypt() async throws {
        // Given
        struct TestModel: Codable, Equatable {
            let id: UUID
            let value: String
            let timestamp: Date
        }
        
        let model = TestModel(
            id: UUID(),
            value: "Test metric",
            timestamp: Date()
        )
        let key = "test.model"
        
        // When
        try await sut.save(model, forKey: key, requiresBiometric: false)
        
        // Then
        XCTAssertEqual(mockKeychain.storedItems.count, 1)
        XCTAssertNotNil(mockKeychain.storedItems[key])
    }
    
    func test_save_withKeychainError_shouldThrowSecureStorageError() async {
        // Given
        let testData = "Test".data(using: .utf8)!
        mockKeychain.shouldFail = true
        mockKeychain.errorToReturn = errSecDuplicateItem
        
        // When/Then
        do {
            try await sut.save(testData, forKey: "test", requiresBiometric: false)
            XCTFail("Expected error")
        } catch {
            guard case SecureStorageError.keychainError(let status) = error else {
                XCTFail("Wrong error type: \(error)")
                return
            }
            XCTAssertEqual(status, errSecDuplicateItem)
        }
    }
    
    // MARK: - Retrieve Tests
    
    func test_retrieveData_shouldDecryptAndReturn() async throws {
        // Given
        let originalData = "Original secret".data(using: .utf8)!
        let key = "test.retrieve"
        
        // First save
        try await sut.save(originalData, forKey: key, requiresBiometric: false)
        
        // When retrieve
        let retrievedData = try await sut.retrieve(key: key)
        
        // Then
        XCTAssertEqual(retrievedData, originalData)
    }
    
    func test_retrieveData_withBiometric_shouldAuthenticateFirst() async throws {
        // Given
        let originalData = "Biometric protected".data(using: .utf8)!
        let key = "test.biometric"
        
        try await sut.save(originalData, forKey: key, requiresBiometric: true)
        
        // When
        mockBiometric.authenticationResult = true
        let retrievedData = try await sut.retrieve(key: key)
        
        // Then
        XCTAssertTrue(mockBiometric.authenticateCalled)
        XCTAssertEqual(retrievedData, originalData)
    }
    
    func test_retrieveData_withBiometricFailure_shouldThrow() async throws {
        // Given
        let key = "test.biometric.fail"
        try await sut.save("data".data(using: .utf8)!, forKey: key, requiresBiometric: true)
        
        mockBiometric.authenticationResult = false
        
        // When/Then
        do {
            _ = try await sut.retrieve(key: key)
            XCTFail("Expected biometric error")
        } catch {
            guard case SecureStorageError.biometricAuthenticationFailed = error else {
                XCTFail("Wrong error type: \(error)")
                return
            }
        }
    }
    
    func test_retrieveCodable_shouldDecodeCorrectly() async throws {
        // Given
        struct TestUser: Codable, Equatable {
            let id: UUID
            let email: String
            let token: String
        }
        
        let user = TestUser(
            id: UUID(),
            email: "test@example.com",
            token: "secret-token-123"
        )
        let key = "test.user"
        
        // Save first
        try await sut.save(user, forKey: key, requiresBiometric: false)
        
        // When retrieve
        let retrieved = try await sut.retrieve(key: key, type: TestUser.self)
        
        // Then
        XCTAssertEqual(retrieved, user)
    }
    
    func test_retrieve_withNonExistentKey_shouldThrowKeyNotFound() async {
        // When/Then
        do {
            _ = try await sut.retrieve(key: "non.existent")
            XCTFail("Expected key not found error")
        } catch {
            guard case SecureStorageError.keyNotFound = error else {
                XCTFail("Wrong error type: \(error)")
                return
            }
        }
    }
    
    // MARK: - Delete Tests
    
    func test_delete_shouldRemoveFromKeychain() async throws {
        // Given
        let key = "test.delete"
        try await sut.save("data".data(using: .utf8)!, forKey: key, requiresBiometric: false)
        
        let exists1 = await sut.exists(key: key)
        XCTAssertTrue(exists1)
        
        // When
        try await sut.delete(key: key)
        
        // Then
        let exists2 = await sut.exists(key: key)
        XCTAssertFalse(exists2)
        XCTAssertNil(mockKeychain.storedItems[key])
    }
    
    func test_delete_nonExistentKey_shouldNotThrow() async throws {
        // Should not throw for non-existent keys
        try await sut.delete(key: "non.existent.key")
    }
    
    // MARK: - Exists Tests
    
    func test_exists_shouldReturnCorrectStatus() async throws {
        // Given
        let key = "test.exists"
        
        // Initially should not exist
        let exists3 = await sut.exists(key: key)
        XCTAssertFalse(exists3)
        
        // After saving should exist
        try await sut.save("data".data(using: .utf8)!, forKey: key, requiresBiometric: false)
        let exists4 = await sut.exists(key: key)
        XCTAssertTrue(exists4)
        
        // After deleting should not exist
        try await sut.delete(key: key)
        let exists5 = await sut.exists(key: key)
        XCTAssertFalse(exists5)
    }
    
    // MARK: - Delete All Tests
    
    func test_deleteAll_shouldRemoveAllStoredItems() async throws {
        // Given - Store multiple items
        try await sut.save("data1".data(using: .utf8)!, forKey: "key1", requiresBiometric: false)
        try await sut.save("data2".data(using: .utf8)!, forKey: "key2", requiresBiometric: true)
        try await sut.save("data3".data(using: .utf8)!, forKey: "key3", requiresBiometric: false)
        
        XCTAssertEqual(mockKeychain.storedItems.count, 3)
        
        // When
        try await sut.deleteAll()
        
        // Then
        XCTAssertEqual(mockKeychain.storedItems.count, 0)
    }
    
    // MARK: - Encryption Tests
    
    func test_encryption_shouldBeUnique() async throws {
        // Given
        let sameData = "Same data".data(using: .utf8)!
        
        // When - Save same data with different keys
        try await sut.save(sameData, forKey: "key1", requiresBiometric: false)
        try await sut.save(sameData, forKey: "key2", requiresBiometric: false)
        
        // Then - Encrypted data should be different (due to unique salt per key)
        let encrypted1 = mockKeychain.storedItems["key1"]?.data
        let encrypted2 = mockKeychain.storedItems["key2"]?.data
        
        XCTAssertNotNil(encrypted1)
        XCTAssertNotNil(encrypted2)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }
    
    func test_dataIntegrity_shouldMaintainAfterMultipleOperations() async throws {
        // Given
        let originalData = "Important health metrics".data(using: .utf8)!
        let key = "test.integrity"
        
        // When - Multiple save/retrieve cycles
        for i in 1...5 {
            let modifiedData = "\(i): \(String(data: originalData, encoding: .utf8)!)".data(using: .utf8)!
            try await sut.save(modifiedData, forKey: key, requiresBiometric: false)
            
            let retrieved = try await sut.retrieve(key: key)
            XCTAssertEqual(retrieved, modifiedData)
        }
    }
}

// MARK: - Mock Keychain Service

private final class MockSecureKeychainService: SecureKeychainProtocol, @unchecked Sendable {
    var storedItems: [String: KeychainItem] = [:]
    var shouldFail = false
    var errorToReturn: OSStatus = errSecItemNotFound
    
    struct KeychainItem {
        let data: Data
        let accessible: KeychainAccessibility
        let requiresBiometric: Bool
    }
    
    func save(
        _ data: Data,
        forKey key: String,
        accessible: KeychainAccessibility,
        requiresBiometric: Bool
    ) throws {
        if shouldFail {
            throw SecureKeychainError.systemError(errorToReturn)
        }
        
        storedItems[key] = KeychainItem(
            data: data,
            accessible: accessible,
            requiresBiometric: requiresBiometric
        )
    }
    
    func retrieve(key: String) throws -> Data {
        guard let item = storedItems[key] else {
            throw SecureKeychainError.itemNotFound
        }
        return item.data
    }
    
    func delete(key: String) throws {
        if shouldFail {
            throw SecureKeychainError.systemError(errorToReturn)
        }
        storedItems.removeValue(forKey: key)
    }
    
    func exists(key: String) -> Bool {
        storedItems[key] != nil
    }
    
    func deleteAll() throws {
        if shouldFail {
            throw SecureKeychainError.systemError(errorToReturn)
        }
        storedItems.removeAll()
    }
    
    func requiresBiometric(key: String) throws -> Bool {
        guard let item = storedItems[key] else {
            throw SecureKeychainError.itemNotFound
        }
        return item.requiresBiometric
    }
}

// MARK: - Mock Biometric Service

private final class MockBiometricService: BiometricServiceProtocol, @unchecked Sendable {
    var authenticateCalled = false
    var authenticationResult = true
    var isAvailable = true
    
    func authenticate(reason: String) async -> Bool {
        authenticateCalled = true
        return authenticationResult
    }
    
    func canUseBiometrics() -> Bool {
        isAvailable
    }
}

// The protocols are now imported from ClarityCore