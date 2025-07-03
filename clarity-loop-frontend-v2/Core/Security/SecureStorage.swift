//
//  SecureStorage.swift
//  clarity-loop-frontend-v2
//
//  Secure storage implementation using CryptoKit and Keychain
//

import Foundation
import CryptoKit
import Security
@preconcurrency import LocalAuthentication

/// Implementation of SecureStorageProtocol using CryptoKit for encryption and Keychain for storage
public final class SecureStorage: SecureStorageProtocol, SecureStorageKeychainAccess {

    // MARK: - Properties

    public let keychainService: SecureKeychainProtocol
    internal let biometricService: BiometricServiceProtocol
    private let encryptionSalt = "clarity.health.encryption.salt"

    // MARK: - Initialization

    public init(
        keychainService: SecureKeychainProtocol? = nil,
        biometricService: BiometricServiceProtocol? = nil
    ) {
        self.keychainService = keychainService ?? SecureKeychainService()
        self.biometricService = biometricService ?? BiometricService()
    }

    // MARK: - SecureStorageProtocol Implementation

    public func save(_ data: Data, forKey key: String, requiresBiometric: Bool) async throws {
        // Encrypt the data
        let encryptedData = try encrypt(data, forKey: key)

        // Determine accessibility based on biometric requirement
        let accessibility: KeychainAccessibility = requiresBiometric
            ? .whenPasscodeSetThisDeviceOnly
            : .whenUnlockedThisDeviceOnly

        // Save to keychain with proper error mapping
        do {
            try keychainService.save(
                encryptedData,
                forKey: key,
                accessible: accessibility,
                requiresBiometric: requiresBiometric
            )
        } catch SecureKeychainError.itemNotFound {
            // This shouldn't happen in save operations, but handle it
            throw SecureStorageError.keychainError(-25300) // errSecItemNotFound
        } catch SecureKeychainError.systemError(let status) {
            throw SecureStorageError.keychainError(status)
        } catch {
            // Catch any other errors and wrap them
            throw SecureStorageError.keychainError(-1)
        }
    }

    public func save<T: Codable>(_ object: T, forKey key: String, requiresBiometric: Bool) async throws {
        do {
            let data = try JSONEncoder().encode(object)
            try await save(data, forKey: key, requiresBiometric: requiresBiometric)
        } catch let error as EncodingError {
            throw SecureStorageError.encodingFailed(error.localizedDescription)
        }
    }

    public func retrieve(key: String) async throws -> Data {
        // Check if biometric authentication is required
        do {
            if try keychainService.requiresBiometric(key: key) {
                let authenticated = await biometricService.authenticate(
                    reason: "Authenticate to access secure health data"
                )

                guard authenticated else {
                    throw SecureStorageError.biometricAuthenticationFailed
                }
            }
        } catch SecureKeychainError.itemNotFound {
            throw SecureStorageError.keyNotFound
        } catch SecureKeychainError.systemError(let status) {
            throw SecureStorageError.keychainError(status)
        }

        // Retrieve encrypted data
        do {
            let encryptedData = try keychainService.retrieve(key: key)
            return try decrypt(encryptedData, forKey: key)
        } catch SecureKeychainError.itemNotFound {
            throw SecureStorageError.keyNotFound
        } catch SecureKeychainError.systemError(let status) {
            throw SecureStorageError.keychainError(status)
        } catch {
            // Catch any other errors and wrap them appropriately
            if error.localizedDescription.contains("itemNotFound") {
                throw SecureStorageError.keyNotFound
            }
            throw SecureStorageError.keychainError(-1)
        }
    }

    public func retrieve<T: Codable>(key: String, type: T.Type) async throws -> T {
        let data = try await retrieve(key: key)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw SecureStorageError.decodingFailed(error.localizedDescription)
        }
    }

    public func delete(key: String) async throws {
        do {
            try keychainService.delete(key: key)
        } catch SecureKeychainError.itemNotFound {
            // Silently ignore if item doesn't exist
            return
        } catch SecureKeychainError.systemError(let status) {
            throw SecureStorageError.keychainError(status)
        }
    }

    public func exists(key: String) async -> Bool {
        keychainService.exists(key: key)
    }

    public func deleteAll() async throws {
        do {
            try keychainService.deleteAll()
        } catch let error as SecureKeychainError {
            throw SecureStorageError.keychainError(error.status)
        }
    }

    // MARK: - Private Encryption Methods

    private func encrypt(_ data: Data, forKey key: String) throws -> Data {
        // Generate a unique salt for this key
        let salt = "\(encryptionSalt).\(key)".data(using: .utf8)!

        // Derive a symmetric key from the salt
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: salt))

        do {
            // Encrypt using AES-GCM
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

            // Combine nonce + ciphertext + tag for storage
            guard let combined = sealedBox.combined else {
                throw SecureStorageError.encryptionFailed("Failed to combine encrypted components")
            }

            return combined
        } catch {
            throw SecureStorageError.encryptionFailed(error.localizedDescription)
        }
    }

    private func decrypt(_ encryptedData: Data, forKey key: String) throws -> Data {
        // Generate the same salt for this key
        let salt = "\(encryptionSalt).\(key)".data(using: .utf8)!

        // Derive the same symmetric key
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: salt))

        do {
            // Create sealed box from combined data
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)

            // Decrypt
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw SecureStorageError.decryptionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Keychain Service

public final class SecureKeychainService: SecureKeychainProtocol {

    private let service = "com.clarity.health.secure"

    public func save(
        _ data: Data,
        forKey key: String,
        accessible: KeychainAccessibility,
        requiresBiometric: Bool
    ) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible.keychainValue
        ]

        // Add biometric protection if required
        if requiresBiometric {
            var error: Unmanaged<CFError>?
            let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessible.keychainValue,
                .biometryCurrentSet,
                &error
            )

            if error != nil {
                throw SecureKeychainError.systemError(-1)
            }

            query[kSecAttrAccessControl as String] = accessControl
        }

        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecureKeychainError.systemError(status)
        }
    }

    public func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecureKeychainError.itemNotFound
            }
            throw SecureKeychainError.systemError(status)
        }

        guard let data = result as? Data else {
            throw SecureStorageError.invalidData
        }

        return data
    }

    public func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureKeychainError.systemError(status)
        }
    }

    public func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureKeychainError.systemError(status)
        }
    }

    public func requiresBiometric(key: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecureKeychainError.itemNotFound
            }
            throw SecureKeychainError.systemError(status)
        }

        // Check if access control includes biometry
        if let attributes = result as? [String: Any],
           let _ = attributes[kSecAttrAccessControl as String] {
            return true
        }

        return false
    }
}

// MARK: - Biometric Service

public final class BiometricService: BiometricServiceProtocol {

    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard canUseBiometrics() else { return false }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    public func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }
}

// MARK: - Keychain Extensions

extension KeychainAccessibility {
    var keychainValue: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

extension SecureKeychainError {
    var status: OSStatus {
        switch self {
        case .itemNotFound:
            return errSecItemNotFound
        case .systemError(let status):
            return status
        }
    }
}
