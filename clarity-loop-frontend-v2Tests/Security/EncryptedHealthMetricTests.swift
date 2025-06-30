//
//  EncryptedHealthMetricTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for encrypted health metric handling
//

import Testing
import Foundation
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

@Suite("Encrypted Health Metric Tests")
struct EncryptedHealthMetricTests {
    
    let secureStorage = SecureStorage()
    
    // MARK: - Encryption Tests
    
    @Test("Health metric values should be encrypted before storage")
    func testHealthMetricEncryption() async throws {
        // Given: A health metric with sensitive data
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .bloodGlucose,
            value: 120.5,
            unit: "mg/dL",
            recordedAt: Date(),
            notes: "After meal reading",
            source: .manual
        )
        
        // When: We encrypt the metric
        let encryptedData = try await secureStorage.encryptHealthMetric(metric)
        
        // Then: The encrypted data should be different from original
        let jsonEncoder = JSONEncoder()
        let originalData = try jsonEncoder.encode(metric)
        #expect(encryptedData != originalData)
        #expect(encryptedData.count > 0)
    }
    
    @Test("Encrypted health metrics should decrypt correctly")
    func testHealthMetricDecryption() async throws {
        // Given: A health metric
        let originalMetric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            recordedAt: Date(),
            notes: "Resting heart rate",
            source: .healthKit
        )
        
        // When: We encrypt and then decrypt
        let encryptedData = try await secureStorage.encryptHealthMetric(originalMetric)
        let decryptedMetric: HealthMetric = try await secureStorage.decryptHealthMetric(from: encryptedData)
        
        // Then: The decrypted metric should match the original
        #expect(decryptedMetric.id == originalMetric.id)
        #expect(decryptedMetric.value == originalMetric.value)
        #expect(decryptedMetric.type == originalMetric.type)
        #expect(decryptedMetric.notes == originalMetric.notes)
    }
    
    @Test("Should handle batch encryption of multiple metrics")
    func testBatchEncryption() async throws {
        // Given: Multiple health metrics
        let metrics = [
            HealthMetric(id: UUID(), userId: UUID(), type: .steps, value: 10000, unit: "steps", recordedAt: Date()),
            HealthMetric(id: UUID(), userId: UUID(), type: .weight, value: 75.5, unit: "kg", recordedAt: Date()),
            HealthMetric(id: UUID(), userId: UUID(), type: .bloodPressureSystolic, value: 120, unit: "mmHg", recordedAt: Date())
        ]
        
        // When: We encrypt all metrics
        let encryptedBatch = try await secureStorage.encryptHealthMetrics(metrics)
        
        // Then: All metrics should be encrypted
        #expect(encryptedBatch.count == metrics.count)
        for encrypted in encryptedBatch {
            #expect(encrypted.data.count > 0)
        }
    }
    
    // MARK: - Network Transmission Tests
    
    @Test("Encrypted metrics should be safe for network transmission")
    func testNetworkSafeEncryption() async throws {
        // Given: A metric with special characters
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .medication,
            value: 1.0,
            unit: "dose",
            recordedAt: Date(),
            notes: "Test with special chars: ñ, é, 中文, 🏥",
            source: .manual
        )
        
        // When: We prepare for network transmission
        let encryptedPayload = try await secureStorage.prepareForTransmission(metric)
        
        // Then: The payload should be base64 encoded
        #expect(encryptedPayload.encryptedData != nil)
        #expect(encryptedPayload.algorithm == "AES-GCM")
        #expect(encryptedPayload.keyId != nil)
        
        // Verify base64 encoding
        let data = Data(base64Encoded: encryptedPayload.encryptedData)
        #expect(data != nil)
    }
    
    // MARK: - Key Rotation Tests
    
    @Test("Should support key rotation for encrypted metrics")
    func testKeyRotation() async throws {
        // Given: An encrypted metric with old key
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .oxygenSaturation,
            value: 98.0,
            unit: "%",
            recordedAt: Date()
        )
        
        let oldEncrypted = try await secureStorage.encryptHealthMetric(metric)
        
        // When: We rotate the encryption key
        try await secureStorage.rotateEncryptionKey()
        
        // Then: Old data should still decrypt, new data uses new key
        let decrypted: HealthMetric = try await secureStorage.decryptHealthMetric(from: oldEncrypted)
        #expect(decrypted.value == metric.value)
        
        // New encryption should use new key
        let newEncrypted = try await secureStorage.encryptHealthMetric(metric)
        #expect(newEncrypted != oldEncrypted)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Should handle decryption errors gracefully")
    func testDecryptionErrorHandling() async throws {
        // Given: Invalid encrypted data
        let invalidData = Data("invalid encrypted data".utf8)
        
        // When/Then: Decryption should throw appropriate error
        await #expect(throws: SecureStorageError.decryptionFailed) {
            let _: HealthMetric = try await secureStorage.decryptHealthMetric(from: invalidData)
        }
    }
    
    @Test("Should validate metric integrity after decryption")
    func testMetricIntegrity() async throws {
        // Given: A metric with calculated checksum
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .caloriesBurned,
            value: 250.0,
            unit: "kcal",
            recordedAt: Date()
        )
        
        // When: We encrypt with integrity check
        let encrypted = try await secureStorage.encryptWithIntegrity(metric)
        
        // Then: Tampering should be detected
        var tamperedData = encrypted
        tamperedData[10] = tamperedData[10] &+ 1 // Modify one byte
        
        await #expect(throws: SecureStorageError.integrityCheckFailed) {
            let _: HealthMetric = try await secureStorage.decryptWithIntegrityCheck(from: tamperedData)
        }
    }
}

// Import the payload structure from the implementation
// EncryptedHealthPayload is defined in SecureStorage+HealthMetrics.swift

// MARK: - Additional Security Error Extensions

extension SecureStorageError {
    static let integrityCheckFailed = SecureStorageError.decryptionFailed("Integrity check failed")
}