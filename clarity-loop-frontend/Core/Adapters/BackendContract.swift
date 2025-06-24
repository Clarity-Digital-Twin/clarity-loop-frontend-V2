import Foundation

// MARK: - Backend Contract DTOs

// These DTOs exactly match the backend API contract

/// Backend registration request model - matches Python UserRegister
struct BackendUserRegister: Codable {
    let email: String
    let password: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case displayName = "display_name"
    }
}

/// Backend login request model - matches Python UserLoginRequest
struct BackendUserLogin: Codable {
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

/// Backend token response model - matches Python TokenResponse
struct BackendTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

/// Backend user info response - matches Python UserInfoResponse
struct BackendUserInfoResponse: Codable {
    let userId: String
    let email: String?
    let emailVerified: Bool
    let displayName: String?
    let authProvider: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case emailVerified = "email_verified"
        case displayName = "display_name"
        case authProvider = "auth_provider"
    }
}

/// Backend user update request - matches Python UserUpdate
struct BackendUserUpdate: Codable {
    let displayName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
    }
}

/// Backend user update response - matches Python UserUpdateResponse
struct BackendUserUpdateResponse: Codable {
    let userId: String
    let email: String?
    let displayName: String?
    let updated: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case displayName = "display_name"
        case updated
    }
}

/// Backend logout response - matches Python LogoutResponse
struct BackendLogoutResponse: Codable {
    let message: String
}

/// Backend health response - matches Python HealthResponse
struct BackendHealthResponse: Codable {
    let status: String
    let service: String
    let version: String
}

/// Backend refresh token request
struct BackendRefreshTokenRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Error Response Models

/// Backend problem detail response for errors
struct BackendProblemDetail: Codable {
    let type: String
    let title: String
    let detail: String
    let status: Int
    let instance: String?
}

/// Backend validation error detail
struct BackendValidationError: Codable {
    let detail: [ValidationErrorDetail]
}

struct ValidationErrorDetail: Codable {
    let loc: [String]
    let msg: String
    let type: String
}
