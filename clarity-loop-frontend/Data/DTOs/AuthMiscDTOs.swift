import Foundation

// MARK: - Token Refresh

/// DTO for the token refresh request body.
struct RefreshTokenRequestDTO: Codable {
    let refreshToken: String
}

// MARK: - Miscellaneous Auth DTOs

/// A generic DTO for API responses that only contain a message.
/// Used for endpoints like logout or verify email.
struct MessageResponseDTO: Codable {
    let message: String
}

/// A generic DTO for representing validation errors from the API.
struct ValidationErrorDTO: Codable {
    let field: String
    let message: String
    let code: String
}

/// A DTO for user privacy preferences.
struct UserPrivacyPreferencesDTO: Codable {
    let shareDataForResearch: Bool
    let enableAnalytics: Bool
    let marketingEmails: Bool
    let pushNotifications: Bool
    let dataRetentionPeriod: Int // in days
    let allowThirdPartyIntegrations: Bool
}

/// DTO for email verification requests.
struct EmailVerificationRequestDTO: Codable {
    let verificationCode: String
    let email: String?
}

/// DTO for password reset requests.
struct PasswordResetRequestDTO: Codable {
    let email: String
    let redirectUrl: String?
}

/// DTO for password reset confirmation.
struct PasswordResetConfirmDTO: Codable {
    let resetToken: String
    let newPassword: String
    let confirmPassword: String
}

/// DTO for registration response when email verification is required (HTTP 202).
struct EmailVerificationRequiredDTO: Codable {
    let requiresEmailVerification: Bool

    enum CodingKeys: String, CodingKey {
        case requiresEmailVerification = "requires_email_verification"
    }
}
