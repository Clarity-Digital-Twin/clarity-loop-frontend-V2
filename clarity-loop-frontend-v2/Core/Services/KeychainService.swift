//
//  KeychainService.swift
//  clarity-loop-frontend-v2
//
//  Secure storage service using iOS Keychain
//

import Foundation
import Security

// MARK: - Protocol

public protocol KeychainServiceProtocol: Sendable {
    func save(_ value: String, forKey key: String) throws
    func retrieve(_ key: String) throws -> String
    func delete(_ key: String) throws
}

// MARK: - Errors

public enum KeychainError: Error, Equatable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)
}

// MARK: - Implementation

public final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    
    private let service = "com.clarity.pulse"
    private let accessGroup: String? = nil
    
    public init() {}
    
    // MARK: - Basic Operations
    
    public func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query = createQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Try to update first
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If not found, add new item
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            status = SecItemAdd(newItem as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func retrieve(_ key: String) throws -> String {
        var query = createQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return value
    }
    
    public func delete(_ key: String) throws {
        let query = createQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Private Helpers
    
    private func createQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}
