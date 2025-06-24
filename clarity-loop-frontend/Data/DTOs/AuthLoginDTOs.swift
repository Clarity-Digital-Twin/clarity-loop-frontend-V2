import Foundation

// MARK: - User Login

/// DTO for the user login request body.
struct UserLoginRequestDTO: Codable {
    let email: String
    let password: String
    let rememberMe: Bool
    let deviceInfo: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case rememberMe = "remember_me"
        case deviceInfo = "device_info"
    }
}

/// DTO for the complete user login response body.
/// This is a composite DTO containing the user session and authentication tokens.
struct LoginResponseDTO: Codable {
    let user: UserSessionResponseDTO
    let tokens: TokenResponseDTO
}

/// DTO representing the user's session information.
struct UserSessionResponseDTO: Codable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
    let provider: String
    let role: String
    let isActive: Bool
    let isEmailVerified: Bool
    let preferences: UserPreferencesResponseDTO?
    let metadata: UserMetadataResponseDTO?

    // Legacy properties for backward compatibility
    var userId: UUID? {
        UUID(uuidString: id)
    }

    var firstName: String {
        displayName.components(separatedBy: " ").first ?? ""
    }

    var lastName: String {
        displayName.components(separatedBy: " ").dropFirst().joined(separator: " ")
    }

    var permissions: [String] {
        []
    }

    var status: String {
        isActive ? "active" : "inactive"
    }

    var mfaEnabled: Bool {
        false
    }

    var emailVerified: Bool {
        isEmailVerified
    }

    var createdAt: Date {
        metadata?.createdAt ?? Date()
    }

    var lastLogin: Date? {
        metadata?.lastLogin
    }
}

/// User preferences DTO
struct UserPreferencesResponseDTO: Codable {
    let theme: String
    let notifications: Bool
    let language: String
}

/// User metadata DTO
struct UserMetadataResponseDTO: Codable {
    let lastLogin: Date
    let loginCount: Int
    let createdAt: Date
    let updatedAt: Date
}

/// Auth tokens response DTO
struct AuthTokensResponseDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// Legacy DTO for backward compatibility
typealias TokenResponseDTO = AuthTokensResponseDTO
