@testable import clarity_loop_frontend
import Combine
import Foundation

@MainActor
class MockAuthService: AuthServiceProtocol {
    var shouldSucceed = true
    var mockUserSession = UserSessionResponseDTO(
        id: UUID().uuidString,
        email: "test@example.com",
        displayName: "Test User",
        avatarUrl: nil,
        provider: "email",
        role: "user",
        isActive: true,
        isEmailVerified: true,
        preferences: UserPreferencesResponseDTO(
            theme: "light",
            notifications: true,
            language: "en"
        ),
        metadata: UserMetadataResponseDTO(
            lastLogin: Date(),
            loginCount: 1,
            createdAt: Date(),
            updatedAt: Date()
        )
    )

    // Mock user state
    var mockCurrentUser: AuthUser? = AuthUser(uid: "test-uid", email: "test@example.com", isEmailVerified: true)
    
    // Tracking properties
    var signOutCalled = false
    var signInCalled = false
    var capturedEmail: String?
    var capturedPassword: String?
    var sendPasswordResetCalled = false
    var capturedResetEmail: String?
    
    // Control properties
    var shouldFailSignIn = false
    var shouldFailPasswordReset = false
    var shouldDelayLogin = false
    var mockError: Error = APIError.unauthorized

    // MARK: - AuthServiceProtocol Implementation

    var authState: AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            continuation.yield(mockCurrentUser)
            continuation.finish()
        }
    }

    var currentUser: AuthUser? {
        mockCurrentUser
    }

    func signIn(withEmail email: String, password: String) async throws -> UserSessionResponseDTO {
        signInCalled = true
        capturedEmail = email
        capturedPassword = password
        
        if shouldDelayLogin {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if shouldFailSignIn {
            throw mockError
        }
        
        if shouldSucceed {
            mockCurrentUser = AuthUser(uid: "signed-in-uid", email: email, isEmailVerified: true)
            return mockUserSession
        } else {
            throw APIError.unauthorized
        }
    }

    func register(
        withEmail email: String,
        password: String,
        details: UserRegistrationRequestDTO
    ) async throws -> RegistrationResponseDTO {
        if shouldSucceed {
            return RegistrationResponseDTO(
                userId: UUID(),
                email: email,
                status: "pending_verification",
                verificationEmailSent: true,
                createdAt: Date()
            )
        } else {
            throw mockError
        }
    }

    func signOut() async throws {
        signOutCalled = true
        mockCurrentUser = nil
    }

    func sendPasswordReset(to email: String) async throws {
        sendPasswordResetCalled = true
        capturedResetEmail = email
        
        if shouldFailPasswordReset {
            throw mockError
        }
        
        if !shouldSucceed {
            throw APIError.serverError(statusCode: 400, message: "Password reset failed")
        }
    }

    func getCurrentUserToken() async throws -> String {
        if shouldSucceed {
            "mock-jwt-token"
        } else {
            throw APIError.unauthorized
        }
    }

    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO {
        if shouldSucceed {
            TokenResponseDTO(
                accessToken: "mock-refreshed-access-token",
                refreshToken: "mock-refreshed-refresh-token",
                tokenType: "Bearer",
                expiresIn: 3600
            )
        } else {
            throw APIError.unauthorized
        }
    }

    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        if shouldSucceed {
            mockCurrentUser = AuthUser(uid: "verified-uid", email: email, isEmailVerified: true)
            return LoginResponseDTO(
                user: mockUserSession,
                tokens: TokenResponseDTO(
                    accessToken: "mock-access-token",
                    refreshToken: "mock-refresh-token",
                    tokenType: "Bearer",
                    expiresIn: 3600
                )
            )
        } else {
            throw APIError.validationError("Invalid verification code")
        }
    }

    func resendVerificationEmail(to email: String) async throws {
        if !shouldSucceed {
            throw APIError.serverError(statusCode: 429, message: "Too many requests")
        }
        // Success - no-op
    }
}
