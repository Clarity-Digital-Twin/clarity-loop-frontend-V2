import Foundation

/// Defines the endpoints for the authentication-related API calls.
enum AuthEndpoint: Endpoint {
    case register(dto: UserRegistrationRequestDTO)
    case login(dto: UserLoginRequestDTO)
    case refreshToken(dto: RefreshTokenRequestDTO)
    case logout
    case getCurrentUser
    case verifyEmail(email: String, code: String)
    case resendVerificationEmail(email: String)

    var path: String {
        switch self {
        case .register:
            "/api/v1/auth/register"
        case .login:
            "/api/v1/auth/login"
        case .refreshToken:
            "/api/v1/auth/refresh"
        case .logout:
            "/api/v1/auth/logout"
        case .getCurrentUser:
            "/api/v1/auth/me"
        case .verifyEmail:
            "/api/v1/auth/verify-email"
        case .resendVerificationEmail:
            "/api/v1/auth/resend-verification"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .refreshToken, .logout, .verifyEmail, .resendVerificationEmail:
            .post
        case .getCurrentUser:
            .get
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .register(dto):
            return try encoder.encode(dto)
        case let .login(dto):
            return try encoder.encode(dto)
        case let .refreshToken(dto):
            return try encoder.encode(dto)
        case let .verifyEmail(email, code):
            let verificationDTO = EmailVerificationRequestDTO(verificationCode: code, email: email)
            return try encoder.encode(verificationDTO)
        case let .resendVerificationEmail(email):
            let resendDTO = ["email": email]
            return try encoder.encode(resendDTO)
        case .logout, .getCurrentUser:
            return nil
        }
    }
}
