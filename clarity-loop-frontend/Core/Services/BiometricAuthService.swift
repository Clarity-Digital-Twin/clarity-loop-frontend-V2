import Foundation
import LocalAuthentication
import Observation
import UIKit

@Observable
final class BiometricAuthService: @unchecked Sendable {
    // MARK: - Properties

    var isBiometricEnabled = false
    var biometricType: LABiometryType = .none
    var isAvailable = false
    var lastAuthenticationDate: Date?

    var context: LAContext = .init()

    private let userDefaults = UserDefaults.standard
    private let biometricEnabledKey = "biometric_auth_enabled"

    var isAppObscured = false
    var shouldBlurOnBackground = true
    var isJailbroken = false

    private var blurView: UIView?

    // MARK: - Initialization

    init() {
        checkBiometricAvailability()
        loadBiometricSettings()
    }

    // MARK: - Public Methods

    func checkBiometricAvailability() {
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func enableBiometricAuth() async throws -> Bool {
        guard isAvailable else {
            throw BiometricError.notAvailable
        }

        let success = try await authenticateWithBiometrics(reason: "Enable biometric authentication for Clarity Pulse")

        if success {
            isBiometricEnabled = true
            saveBiometricSettings()
        }

        return success
    }

    func disableBiometricAuth() {
        isBiometricEnabled = false
        saveBiometricSettings()
    }

    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        guard isAvailable else {
            throw BiometricError.notAvailable
        }

        guard isBiometricEnabled else {
            throw BiometricError.notEnabled
        }

        return try await withCheckedThrowingContinuation { continuation in
            let context = LAContext()
            context.localizedFallbackTitle = "Use Passcode"

            context
                .evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                    if success {
                        DispatchQueue.main.async {
                            self.lastAuthenticationDate = Date()
                        }
                        continuation.resume(returning: true)
                    } else if let error {
                        continuation.resume(throwing: self.mapLAError(error))
                    } else {
                        continuation.resume(throwing: BiometricError.unknown)
                    }
                }
        }
    }

    func authenticateForAppUnlock() async throws -> Bool {
        let reason = "Unlock Clarity Pulse to access your health data"
        return try await authenticateWithBiometrics(reason: reason)
    }

    func shouldRequireAuthentication() -> Bool {
        guard isBiometricEnabled else { return false }

        // Require authentication if no recent authentication or app was backgrounded
        guard let lastAuth = lastAuthenticationDate else { return true }

        // Require re-authentication after 5 minutes of inactivity
        let timeInterval = Date().timeIntervalSince(lastAuth)
        return timeInterval > 300 // 5 minutes
    }

    var biometricTypeDescription: String {
        switch biometricType {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        case .opticID:
            "Optic ID"
        case .none:
            "Biometric Authentication"
        @unknown default:
            "Biometric Authentication"
        }
    }

    // MARK: - Private Methods

    private func loadBiometricSettings() {
        isBiometricEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }

    private func saveBiometricSettings() {
        userDefaults.set(isBiometricEnabled, forKey: biometricEnabledKey)
    }

    private func mapLAError(_ error: Error) -> BiometricError {
        guard let laError = error as? LAError else {
            return BiometricError.unknown
        }

        switch laError.code {
        case .userCancel:
            return BiometricError.userCancel
        case .userFallback:
            return BiometricError.userFallback
        case .systemCancel:
            return BiometricError.systemCancel
        case .passcodeNotSet:
            return BiometricError.passcodeNotSet
        case .biometryNotAvailable:
            return BiometricError.notAvailable
        case .biometryNotEnrolled:
            return BiometricError.notEnrolled
        case .biometryLockout:
            return BiometricError.lockout
        case .authenticationFailed:
            return BiometricError.authenticationFailed
        default:
            return BiometricError.unknown
        }
    }
}

// MARK: - BiometricError

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnabled
    case notEnrolled
    case passcodeNotSet
    case userCancel
    case userFallback
    case systemCancel
    case lockout
    case authenticationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Biometric authentication is not available on this device."
        case .notEnabled:
            "Biometric authentication is not enabled for this app."
        case .notEnrolled:
            "No biometric data is enrolled on this device."
        case .passcodeNotSet:
            "A device passcode must be set to use biometric authentication."
        case .userCancel:
            "Authentication was cancelled by the user."
        case .userFallback:
            "User chose to use passcode instead."
        case .systemCancel:
            "Authentication was cancelled by the system."
        case .lockout:
            "Biometric authentication is locked out. Please try again later."
        case .authenticationFailed:
            "Biometric authentication failed."
        case .unknown:
            "An unknown error occurred during authentication."
        }
    }
}
