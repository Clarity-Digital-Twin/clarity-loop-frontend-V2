import Foundation
import SwiftUI

/// A view model that manages the state and logic for the user registration screen.
@MainActor
@Observable
final class RegistrationViewModel {
    // MARK: - Published Properties

    var email = ""
    var password = ""
    var confirmPassword = ""
    var firstName = ""
    var lastName = ""

    var termsAccepted = false
    var privacyPolicyAccepted = false

    var isLoading = false
    var errorMessage: String?
    var registrationComplete = false
    var needsEmailVerification = false

    // MARK: - Computed Validation Properties

    /// Real-time password matching validation
    var isPasswordMatching: Bool {
        password == confirmPassword && !password.isEmpty
    }

    /// Password mismatch error message
    var passwordMismatchError: String? {
        if password.isEmpty || confirmPassword.isEmpty {
            return nil
        }
        return password == confirmPassword ? nil : "Passwords do not match"
    }

    /// Password strength validation
    var isPasswordValid: Bool {
        password.count >= 8 &&
            password.contains(where: \.isUppercase) &&
            password.contains(where: \.isLowercase) &&
            password.contains(where: \.isNumber)
    }

    /// Password validation error messages
    var passwordErrors: [String] {
        var errors: [String] = []

        if password.count < 8 {
            errors.append("Password must be at least 8 characters long")
        }

        if !password.contains(where: \.isUppercase) {
            errors.append("Password must contain at least one uppercase letter")
        }

        if !password.contains(where: \.isLowercase) {
            errors.append("Password must contain at least one lowercase letter")
        }

        if !password.contains(where: \.isNumber) {
            errors.append("Password must contain at least one number")
        }

        return errors
    }

    /// Email validation
    var isEmailValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }

    /// Complete form validation
    var isFormValid: Bool {
        !firstName.isEmpty &&
            !lastName.isEmpty &&
            isEmailValid &&
            isPasswordValid &&
            isPasswordMatching &&
            hasAcceptedTerms &&
            hasAcceptedPrivacy
    }

    /// Terms acceptance (alias for compatibility)
    var hasAcceptedTerms: Bool {
        get { termsAccepted }
        set { termsAccepted = newValue }
    }

    /// Privacy policy acceptance (alias for compatibility)
    var hasAcceptedPrivacy: Bool {
        get { privacyPolicyAccepted }
        set { privacyPolicyAccepted = newValue }
    }

    /// Registration success status (alias for compatibility)
    var isRegistrationSuccessful: Bool {
        registrationComplete
    }

    // MARK: - Private Properties

    private let authService: AuthServiceProtocol

    // MARK: - Initializer

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    // MARK: - Public Methods

    /// Attempts to register a new user with the provided details.
    @MainActor
    func register() async {
        isLoading = true
        errorMessage = nil

        // Validate inputs first
        guard validateInputs() else {
            isLoading = false
            return
        }

        let details = UserRegistrationRequestDTO(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: nil,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted
        )

        do {
            _ = try await authService.register(withEmail: email, password: password, details: details)
            // If we get here, registration was successful (200 response)
            registrationComplete = true
            needsEmailVerification = false
            errorMessage = nil
        } catch let error as APIError {
            // Handle specific API errors
            if case .emailVerificationRequired = error {
                // This is a 202 response - registration successful but email verification required
                registrationComplete = true
                needsEmailVerification = true
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Validation

    private func validateInputs() -> Bool {
        guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = "All fields are required."
            return false
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }

        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return false
        }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters long."
            return false
        }

        guard termsAccepted, privacyPolicyAccepted else {
            errorMessage = "You must accept the Terms of Service and Privacy Policy."
            return false
        }

        // Add more robust email/password validation as needed

        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
