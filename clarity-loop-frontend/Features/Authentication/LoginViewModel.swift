import Foundation
import SwiftUI

/// A view model that manages the state and logic for the login screen.
@MainActor
@Observable
final class LoginViewModel {
    // MARK: - Published Properties

    var email = ""
    var password = ""
    var errorMessage: String?
    var isLoading = false
    var shouldShowEmailVerification = false

    // MARK: - Private Properties

    private let authService: AuthServiceProtocol

    // MARK: - Initializer

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    // MARK: - Public Methods

    /// Attempts to sign in the user with the provided credentials.
    func login() async {
        isLoading = true
        errorMessage = nil
        shouldShowEmailVerification = false

        do {
            _ = try await authService.signIn(withEmail: email, password: password)
            // On success, the AuthViewModel observing the auth state will trigger the UI change.
        } catch {
            if let apiError = error as? APIError, case .emailVerificationRequired = apiError {
                // Email verification is required - navigate to verification screen
                shouldShowEmailVerification = true
                errorMessage = nil // Don't show error since we're navigating to verification
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Sends a password reset email to the entered email address.
    func requestPasswordReset() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.sendPasswordReset(to: email)
            // Optionally, set a message to inform the user to check their email.
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
