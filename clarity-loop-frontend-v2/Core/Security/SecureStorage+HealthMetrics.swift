//
//  SecureStorage+HealthMetrics.swift
//  clarity-loop-frontend-v2
//
//  Extensions for encrypting health metrics
//

import Foundation
import CryptoKit
import ClarityDomain

// MARK: - Encrypted Payload Structure

public struct EncryptedHealthPayload: Codable, Sendable {
    public let encryptedData: String // Base64 encoded
    public let algorithm: String
    public let keyId: String
    public let timestamp: Date
    public let nonce: String // Base64 encoded nonce for AES-GCM
    
    public init(
        encryptedData: String,
        algorithm: String,
        keyId: String,
        timestamp: Date,
        nonce: String
    ) {
        self.encryptedData = encryptedData
        self.algorithm = algorithm
        self.keyId = keyId
        self.timestamp = timestamp
        self.nonce = nonce
    }
}

// MARK: - Health Metric Encryption

extension SecureStorage {
    
    private static let healthMetricKeyPrefix = "health.metric.key."
    private static let currentKeyIdKey = "health.metric.current.key.id"
    
    /// Encrypt a health metric for secure storage or transmission
    public func encryptHealthMetric(_ metric: HealthMetric) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metric)
        
        // Generate a unique key for health metrics if not exists
        let keyId = try await getCurrentKeyId()
        let encryptionKey = try await getOrCreateHealthMetricKey(keyId: keyId)
        
        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        
        // Combine nonce + ciphertext + tag
        guard let combinedData = sealedBox.combined else {
            throw SecureStorageError.encryptionFailed("Failed to create combined encrypted data")
        }
        
        return combinedData
    }
    
    /// Decrypt a health metric from encrypted data
    public func decryptHealthMetric(from encryptedData: Data) async throws -> HealthMetric {
        // Get current key (will try multiple keys if needed for key rotation)
        let keyId = try await getCurrentKeyId()
        let encryptionKey = try await getHealthMetricKey(keyId: keyId)
        
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        
        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HealthMetric.self, from: decryptedData)
    }
    
    /// Encrypt multiple health metrics in batch
    public func encryptHealthMetrics(_ metrics: [HealthMetric]) async throws -> [(id: UUID, data: Data)] {
        try await withThrowingTaskGroup(of: (UUID, Data).self) { group in
            for metric in metrics {
                group.addTask {
                    let encrypted = try await self.encryptHealthMetric(metric)
                    return (metric.id, encrypted)
                }
            }
            
            var results: [(id: UUID, data: Data)] = []
            for try await result in group {
                results.append((id: result.0, data: result.1))
            }
            return results
        }
    }
    
    /// Prepare encrypted metric for network transmission
    public func prepareForTransmission(_ metric: HealthMetric) async throws -> EncryptedHealthPayload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metric)
        
        let keyId = try await getCurrentKeyId()
        let encryptionKey = try await getOrCreateHealthMetricKey(keyId: keyId)
        
        // Generate nonce explicitly for transmission
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey, nonce: nonce)
        
        return EncryptedHealthPayload(
            encryptedData: sealedBox.ciphertext.base64EncodedString(),
            algorithm: "AES-GCM-256",
            keyId: keyId,
            timestamp: Date(),
            nonce: Data(nonce).base64EncodedString()
        )
    }
    
    /// Rotate encryption key for health metrics
    public func rotateEncryptionKey() async throws {
        // Generate new key
        let newKeyId = UUID().uuidString
        let newKey = SymmetricKey(size: .bits256)
        
        // Save new key to keychain
        try keychainService.save(
            newKey.rawRepresentation,
            forKey: "\(Self.healthMetricKeyPrefix)\(newKeyId)",
            accessible: KeychainAccessibility.whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        
        // Update current key ID
        try keychainService.save(
            Data(newKeyId.utf8),
            forKey: Self.currentKeyIdKey,
            accessible: KeychainAccessibility.whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
    }
    
    /// Encrypt with integrity check (HMAC)
    public func encryptWithIntegrity(_ metric: HealthMetric) async throws -> Data {
        // First encrypt the metric
        let encryptedData = try await encryptHealthMetric(metric)
        
        // Generate HMAC for integrity
        let keyId = try await getCurrentKeyId()
        let hmacKey = try await getOrCreateHMACKey(keyId: keyId)
        
        let hmac = HMAC<SHA256>.authenticationCode(for: encryptedData, using: hmacKey)
        
        // Combine encrypted data + HMAC
        var combinedData = encryptedData
        combinedData.append(Data(hmac))
        
        return combinedData
    }
    
    /// Decrypt with integrity check
    public func decryptWithIntegrityCheck(from data: Data) async throws -> HealthMetric {
        // Split data and HMAC (HMAC is always 32 bytes for SHA256)
        guard data.count > 32 else {
            throw SecureStorageError.decryptionFailed("Invalid data format")
        }
        
        let hmacSize = 32
        let encryptedData = data.prefix(data.count - hmacSize)
        let providedHMAC = data.suffix(hmacSize)
        
        // Verify HMAC
        let keyId = try await getCurrentKeyId()
        let hmacKey = try await getOrCreateHMACKey(keyId: keyId)
        
        let calculatedHMAC = HMAC<SHA256>.authenticationCode(for: encryptedData, using: hmacKey)
        
        guard Data(calculatedHMAC) == providedHMAC else {
            throw SecureStorageError.decryptionFailed("Integrity check failed")
        }
        
        // Decrypt if integrity check passes
        return try await decryptHealthMetric(from: Data(encryptedData))
    }
    
    // MARK: - Private Helper Methods
    
    internal func getCurrentKeyId() async throws -> String {
        if let keyIdData = try? keychainService.retrieve(key: Self.currentKeyIdKey),
           let keyId = String(data: keyIdData, encoding: .utf8) {
            return keyId
        }
        
        // Generate first key ID
        let keyId = UUID().uuidString
        try keychainService.save(
            Data(keyId.utf8),
            forKey: Self.currentKeyIdKey,
            accessible: KeychainAccessibility.whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        return keyId
    }
    
    private func getOrCreateHealthMetricKey(keyId: String) async throws -> SymmetricKey {
        let keyName = "\(Self.healthMetricKeyPrefix)\(keyId)"
        
        if let keyData = try? keychainService.retrieve(key: keyName) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        try keychainService.save(
            newKey.rawRepresentation,
            forKey: keyName,
            accessible: KeychainAccessibility.whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        
        return newKey
    }
    
    private func getHealthMetricKey(keyId: String) async throws -> SymmetricKey {
        let keyName = "\(Self.healthMetricKeyPrefix)\(keyId)"
        
        guard let keyData = try? keychainService.retrieve(key: keyName) else {
            throw SecureStorageError.keyNotFound
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func getOrCreateHMACKey(keyId: String) async throws -> SymmetricKey {
        let keyName = "health.metric.hmac.key.\(keyId)"
        
        if let keyData = try? keychainService.retrieve(key: keyName) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new HMAC key
        let newKey = SymmetricKey(size: .bits256)
        try keychainService.save(
            newKey.rawRepresentation,
            forKey: keyName,
            accessible: KeychainAccessibility.whenUnlockedThisDeviceOnly,
            requiresBiometric: false
        )
        
        return newKey
    }
}

// MARK: - SymmetricKey Extension

extension SymmetricKey {
    var rawRepresentation: Data {
        return withUnsafeBytes { Data($0) }
    }
}
