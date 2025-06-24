import Foundation

// MARK: - User Registration

/// DTO for the user registration request body.
struct UserRegistrationRequestDTO: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?
    let termsAccepted: Bool
    let privacyPolicyAccepted: Bool
}

/// DTO for the user registration response body.
struct RegistrationResponseDTO: Codable {
    let userId: UUID
    let email: String
    let status: String
    let verificationEmailSent: Bool
    let createdAt: Date
}
