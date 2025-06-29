//
//  SecureStorageProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for secure data storage with encryption
//

import Foundation

/// Protocol defining secure storage operations with encryption
public protocol SecureStorageProtocol: Sendable {
    
    /// Save data securely with encryption
    /// - Parameters:
    ///   - data: The data to encrypt and store
    ///   - key: The storage key
    ///   - requiresBiometric: Whether biometric authentication is required for access
    /// - Throws: SecureStorageError if operation fails
    func save(_ data: Data, forKey key: String, requiresBiometric: Bool) async throws
    
    /// Save a Codable object securely with encryption
    /// - Parameters:
    ///   - object: The object to encrypt and store
    ///   - key: The storage key
    ///   - requiresBiometric: Whether biometric authentication is required for access
    /// - Throws: SecureStorageError if operation fails
    func save<T: Codable>(_ object: T, forKey key: String, requiresBiometric: Bool) async throws
    
    /// Retrieve and decrypt data
    /// - Parameters:
    ///   - key: The storage key
    /// - Returns: The decrypted data
    /// - Throws: SecureStorageError if operation fails
    func retrieve(key: String) async throws -> Data
    
    /// Retrieve and decrypt a Codable object
    /// - Parameters:
    ///   - key: The storage key
    ///   - type: The type to decode
    /// - Returns: The decrypted and decoded object
    /// - Throws: SecureStorageError if operation fails
    func retrieve<T: Codable>(key: String, type: T.Type) async throws -> T
    
    /// Delete secure data
    /// - Parameters:
    ///   - key: The storage key
    /// - Throws: SecureStorageError if operation fails
    func delete(key: String) async throws
    
    /// Check if data exists for key
    /// - Parameters:
    ///   - key: The storage key
    /// - Returns: true if data exists
    func exists(key: String) async -> Bool
    
    /// Delete all secure data (use with caution)
    /// - Throws: SecureStorageError if operation fails
    func deleteAll() async throws
}

/// Errors that can occur during secure storage operations
public enum SecureStorageError: LocalizedError, Equatable {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keyNotFound
    case biometricAuthenticationFailed
    case keychainError(OSStatus)
    case invalidData
    case encodingFailed(String)
    case decodingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .keyNotFound:
            return "Key not found in secure storage"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        }
    }
}