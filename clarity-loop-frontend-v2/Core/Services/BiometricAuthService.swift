//
//  BiometricAuthService.swift
//  clarity-loop-frontend-v2
//
//  Biometric authentication service for HIPAA compliance
//

import Foundation
import LocalAuthentication

// MARK: - Protocol

public protocol BiometricAuthServiceProtocol: Sendable {
    func isBiometricAvailable() -> Bool
    var biometricType: BiometricType { get }
    func authenticate(reason: String, fallback: (() async -> Bool)?) async throws -> Bool
}

// MARK: - Types

public enum BiometricType: String {
    case none = "None"
    case touchID = "Touch ID"
    case faceID = "Face ID"
    case opticID = "Optic ID"
}

public enum BiometricAuthError: Error, Equatable {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case userCancelled
    case userFallback
    case authenticationFailed
    case systemError(String)
}

// MARK: - Implementation

public final class BiometricAuthService: BiometricAuthServiceProtocol {
    
    private let context: LAContext
    
    public init(context: LAContext = LAContext()) {
        self.context = context
    }
    
    // MARK: - BiometricAuthServiceProtocol
    
    public func isBiometricAvailable() -> Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        return canEvaluate
    }
    
    public var biometricType: BiometricType {
        guard isBiometricAvailable() else { return .none }
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
    
    @MainActor
    public func authenticate(
        reason: String,
        fallback: (() async -> Bool)? = nil
    ) async throws -> Bool {
        
        // Check if biometric is available
        guard isBiometricAvailable() else {
            throw BiometricAuthError.biometryNotAvailable
        }
        
        // Set fallback button title if provided
        if fallback != nil {
            context.localizedFallbackTitle = "Use Passcode"
        } else {
            context.localizedFallbackTitle = ""
        }
        
        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                throw BiometricAuthError.userCancelled
                
            case .userFallback:
                if let fallback = fallback {
                    return await fallback()
                }
                throw BiometricAuthError.userFallback
                
            case .biometryNotAvailable:
                throw BiometricAuthError.biometryNotAvailable
                
            case .biometryNotEnrolled:
                throw BiometricAuthError.biometryNotEnrolled
                
            case .biometryLockout:
                throw BiometricAuthError.biometryLockout
                
            case .authenticationFailed:
                throw BiometricAuthError.authenticationFailed
                
            default:
                throw BiometricAuthError.systemError(error.localizedDescription)
            }
        } catch {
            throw BiometricAuthError.systemError(error.localizedDescription)
        }
    }
}