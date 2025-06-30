//
//  SecureKeychainProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for secure keychain operations
//

import Foundation

/// Protocol defining secure keychain storage operations
public protocol SecureKeychainProtocol: Sendable {
    
    /// Save data to keychain with specified accessibility
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The keychain key
    ///   - accessible: Accessibility level for the item
    ///   - requiresBiometric: Whether biometric authentication is required
    /// - Throws: SecureKeychainError if operation fails
    func save(
        _ data: Data,
        forKey key: String,
        accessible: KeychainAccessibility,
        requiresBiometric: Bool
    ) throws
    
    /// Retrieve data from keychain
    /// - Parameters:
    ///   - key: The keychain key
    /// - Returns: The stored data
    /// - Throws: SecureKeychainError if operation fails
    func retrieve(key: String) throws -> Data
    
    /// Delete data from keychain
    /// - Parameters:
    ///   - key: The keychain key
    /// - Throws: SecureKeychainError if operation fails
    func delete(key: String) throws
    
    /// Check if data exists for key
    /// - Parameters:
    ///   - key: The keychain key
    /// - Returns: true if data exists
    func exists(key: String) -> Bool
    
    /// Delete all items from keychain
    /// - Throws: SecureKeychainError if operation fails
    func deleteAll() throws
    
    /// Check if item requires biometric authentication
    /// - Parameters:
    ///   - key: The keychain key
    /// - Returns: true if biometric is required
    /// - Throws: SecureKeychainError if operation fails
    func requiresBiometric(key: String) throws -> Bool
}

/// Keychain accessibility options
public enum KeychainAccessibility: Sendable {
    case whenUnlockedThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly
}

/// Errors that can occur during secure keychain operations
public enum SecureKeychainError: LocalizedError, Sendable {
    case itemNotFound
    case systemError(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .systemError(let status):
            return "Keychain error: \(status)"
        }
    }
}
