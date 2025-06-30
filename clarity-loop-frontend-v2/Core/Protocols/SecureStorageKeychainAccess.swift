//
//  SecureStorageKeychainAccess.swift
//  clarity-loop-frontend-v2
//
//  Protocol to provide controlled access to keychain service
//

import Foundation

/// Protocol that provides controlled access to the keychain service
public protocol SecureStorageKeychainAccess {
    /// The keychain service used for secure storage
    var keychainService: SecureKeychainProtocol { get }
}