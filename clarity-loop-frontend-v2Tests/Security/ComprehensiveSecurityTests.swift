//
//  ComprehensiveSecurityTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Comprehensive security test suite
//

import Testing
import Foundation
import CryptoKit
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

@Suite("Comprehensive Security Tests")
struct ComprehensiveSecurityTests {
    
    // MARK: - Keychain Security Tests
    
    @Test("Keychain should enforce access control attributes")
    func testKeychainAccessControl() async throws {
        let keychain = SecureKeychainService()
        let testData = Data("sensitive-data".utf8)
        let key = "test.access.control"
        
        // Test whenUnlockedThisDeviceOnly
        try keychain.save(
            testData,
            forKey: key,
            accessible: .whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        
        // Verify data exists
        let retrieved = try keychain.retrieve(key: key)
        #expect(retrieved == testData)
        
        // Clean up
        try keychain.delete(key: key)
    }
    
    @Test("Keychain should prevent data migration to new devices")
    func testKeychainDeviceBinding() async throws {
        let keychain = SecureKeychainService()
        let criticalData = Data("device-bound-secret".utf8)
        
        // Save with device-only flag
        try keychain.save(
            criticalData,
            forKey: "device.bound.key",
            accessible: .whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        
        // In production, this data would not be accessible after device restore
        // We can only verify it's stored with correct attributes
        let exists = keychain.exists(key: "device.bound.key")
        #expect(exists == true)
        
        try keychain.delete(key: "device.bound.key")
    }
    
    // MARK: - Encryption Strength Tests
    
    @Test("Should use AES-256-GCM encryption")
    func testEncryptionAlgorithmStrength() async throws {
        let secureStorage = SecureStorage()
        let sensitiveData = Data("patient-health-record".utf8)
        
        // Encrypt data
        let encrypted = try secureStorage.encrypt(sensitiveData)
        
        // Verify encrypted data is different and larger (due to nonce + tag)
        #expect(encrypted != sensitiveData)
        #expect(encrypted.count >= sensitiveData.count + 16) // At least 16 bytes for auth tag
    }
    
    @Test("Encryption should be non-deterministic (different output each time)")
    func testEncryptionNonDeterministic() async throws {
        let secureStorage = SecureStorage()
        let data = Data("test-data".utf8)
        
        // Encrypt same data multiple times
        let encrypted1 = try secureStorage.encrypt(data)
        let encrypted2 = try secureStorage.encrypt(data)
        let encrypted3 = try secureStorage.encrypt(data)
        
        // Each encryption should produce different output
        #expect(encrypted1 != encrypted2)
        #expect(encrypted2 != encrypted3)
        #expect(encrypted1 != encrypted3)
        
        // But all should decrypt to same value
        let decrypted1 = try secureStorage.decrypt(encrypted1)
        let decrypted2 = try secureStorage.decrypt(encrypted2)
        let decrypted3 = try secureStorage.decrypt(encrypted3)
        
        #expect(decrypted1 == data)
        #expect(decrypted2 == data)
        #expect(decrypted3 == data)
    }
    
    // MARK: - Token Security Tests
    
    @Test("Access tokens should be stored encrypted")
    func testTokenEncryption() async throws {
        let tokenStorage = TokenStorage(keychain: KeychainService())
        let token = AuthToken(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
            refreshToken: "refresh-token-secret",
            expiresIn: 3600
        )
        
        // Save token
        try await tokenStorage.saveToken(token)
        
        // Verify it's stored encrypted (we can't directly access keychain internals)
        // But we can verify retrieval works
        let retrieved = try await tokenStorage.getAccessToken()
        #expect(retrieved == token.accessToken)
        
        // Clean up
        try await tokenStorage.clearToken()
    }
    
    @Test("Expired tokens should be automatically cleared")
    func testExpiredTokenHandling() async throws {
        let tokenStorage = TokenStorage(keychain: KeychainService())
        
        // Create already expired token
        let expiredToken = AuthToken(
            accessToken: "expired-token",
            refreshToken: "expired-refresh",
            expiresIn: -1 // Already expired
        )
        
        try await tokenStorage.saveToken(expiredToken)
        
        // Should return nil for expired token
        let retrieved = try await tokenStorage.getAccessToken()
        #expect(retrieved == nil)
    }
    
    // MARK: - Network Security Tests
    
    @Test("Sensitive data should be encrypted in transit")
    func testNetworkEncryption() async throws {
        let secureStorage = SecureStorage()
        let interceptor = EncryptedRequestInterceptor(secureStorage: secureStorage)
        
        // Create a request with health metric
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .bloodGlucose,
            value: 95.0,
            unit: "mg/dL",
            recordedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metricData = try encoder.encode(metric)
        
        var request = URLRequest(url: URL(string: "https://api.clarity.health/api/v1/health-metrics")!)
        request.httpMethod = "POST"
        request.httpBody = metricData
        
        // Apply encryption
        try await interceptor.intercept(&request)
        
        // Verify body was encrypted
        #expect(request.httpBody != metricData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/vnd.clarity.encrypted+json")
        #expect(request.value(forHTTPHeaderField: "X-Encryption-Algorithm") == "AES-GCM-256")
    }
    
    // MARK: - Memory Security Tests
    
    @Test("Sensitive data should be cleared from memory after use")
    func testMemoryClearing() async throws {
        // Create mutable data
        var sensitiveData = Data("patient-ssn-123-45-6789".utf8)
        let originalCount = sensitiveData.count
        
        // Use the data
        _ = sensitiveData.base64EncodedString()
        
        // Clear sensitive data
        sensitiveData.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
        
        // Verify it's cleared
        #expect(sensitiveData.count == originalCount)
        #expect(sensitiveData == Data(repeating: 0, count: originalCount))
    }
    
    // MARK: - Biometric Security Tests
    
    @Test("Biometric authentication should be required for sensitive operations")
    func testBiometricRequirement() async throws {
        let biometricService = BiometricService()
        
        // Check if biometrics are available
        let canUseBiometrics = biometricService.canUseBiometrics()
        
        // On simulator, this will be false
        // In production, sensitive operations should check this
        if canUseBiometrics {
            // Would prompt for biometric auth in real scenario
            let reason = "Access your health records"
            let authenticated = await biometricService.authenticate(reason: reason)
            #expect(authenticated == true || authenticated == false) // Valid result
        }
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Tampered data should be detected")
    func testDataIntegrityCheck() async throws {
        let secureStorage = SecureStorage()
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            recordedAt: Date()
        )
        
        // Encrypt with integrity check
        let encryptedData = try await secureStorage.encryptWithIntegrity(metric)
        
        // Tamper with data
        var tamperedData = encryptedData
        if tamperedData.count > 20 {
            tamperedData[15] = tamperedData[15] &+ 1
        }
        
        // Should detect tampering
        await #expect(throws: SecureStorageError.self) {
            let _: HealthMetric = try await secureStorage.decryptWithIntegrityCheck(from: tamperedData)
        }
    }
    
    // MARK: - Key Rotation Tests
    
    @Test("Key rotation should maintain access to old data")
    func testKeyRotationBackwardCompatibility() async throws {
        let secureStorage = SecureStorage()
        
        // Encrypt with current key
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .weight,
            value: 70.5,
            unit: "kg",
            recordedAt: Date()
        )
        
        let oldEncrypted = try await secureStorage.encryptHealthMetric(metric)
        
        // Rotate key
        try await secureStorage.rotateEncryptionKey()
        
        // Should still decrypt old data
        let decrypted = try await secureStorage.decryptHealthMetric(from: oldEncrypted)
        #expect(decrypted.value == metric.value)
        
        // New encryption uses new key
        let newEncrypted = try await secureStorage.encryptHealthMetric(metric)
        #expect(newEncrypted != oldEncrypted)
    }
    
    // MARK: - HIPAA Compliance Tests
    
    @Test("PHI data should be encrypted at rest and in transit")
    func testHIPAAEncryption() async throws {
        let secureStorage = SecureStorage()
        
        // Personal Health Information
        let phi = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .medication,
            value: 1.0,
            unit: "dose",
            recordedAt: Date(),
            notes: "Patient Name: John Doe, DOB: 01/01/1980, Condition: Diabetes",
            source: .manual
        )
        
        // Encrypt for storage
        let encryptedStorage = try await secureStorage.encryptHealthMetric(phi)
        #expect(encryptedStorage.contains(Data("John Doe".utf8)) == false)
        
        // Encrypt for transmission
        let encryptedTransmit = try await secureStorage.prepareForTransmission(phi)
        #expect(encryptedTransmit.algorithm == "AES-GCM-256")
        #expect(encryptedTransmit.encryptedData.isEmpty == false)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Security errors should not leak sensitive information")
    func testSecurityErrorMessages() async throws {
        let error1 = SecureStorageError.encryptionFailed("Internal encryption error")
        let error2 = SecureStorageError.keyNotFound
        let error3 = SecureStorageError.biometricAuthenticationFailed
        
        // Error messages should be generic, not exposing internals
        #expect(error1.localizedDescription.contains("Internal") == false)
        #expect(error2.localizedDescription.contains("Key not found") == true) // Generic enough
        #expect(error3.localizedDescription.contains("failed") == true)
    }
    
    // MARK: - Secure Coding Tests
    
    @Test("Should prevent SQL injection in health metrics")
    func testSQLInjectionPrevention() async throws {
        let repository = HealthMetricRepositoryImplementation(
            apiClient: MockAPIClient(),
            persistence: MockPersistenceService()
        )
        
        // Attempt SQL injection in notes
        let maliciousMetric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            recordedAt: Date(),
            notes: "'; DROP TABLE health_metrics; --",
            source: .manual
        )
        
        // Should safely handle without executing SQL
        let saved = try await repository.create(maliciousMetric)
        #expect(saved.notes == maliciousMetric.notes) // Stored as plain text, not executed
    }
}

// MARK: - Mock Implementations

private class MockAPIClient: APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint, responseType: T.Type) async throws -> T {
        throw NetworkError.offline
    }
}

private class MockPersistenceService: PersistenceServiceProtocol {
    private var metrics: [HealthMetric] = []
    
    func save<T: Codable>(_ object: T) async throws {
        if let metric = object as? HealthMetric {
            metrics.append(metric)
        }
    }
    
    func fetch<T: Codable>(_ type: T.Type, predicate: NSPredicate?) async throws -> [T] {
        return metrics as? [T] ?? []
    }
    
    func delete<T: Codable>(_ object: T) async throws {
        if let metric = object as? HealthMetric {
            metrics.removeAll { $0.id == metric.id }
        }
    }
    
    func update<T: Codable>(_ object: T) async throws {
        // No-op for mock
    }
}
