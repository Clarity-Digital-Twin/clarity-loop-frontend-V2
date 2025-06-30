//
//  BiometricServiceProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for biometric authentication operations
//

import Foundation

/// Protocol defining biometric authentication operations
public protocol BiometricServiceProtocol: Sendable {
    
    /// Authenticate using biometrics
    /// - Parameters:
    ///   - reason: The reason shown to user for authentication
    /// - Returns: true if authentication succeeded
    func authenticate(reason: String) async -> Bool
    
    /// Check if biometric authentication is available
    /// - Returns: true if biometrics can be used
    func canUseBiometrics() -> Bool
}
