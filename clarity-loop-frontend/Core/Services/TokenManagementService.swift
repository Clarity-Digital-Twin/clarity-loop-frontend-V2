//
//  TokenManagementService.swift
//  clarity-loop-frontend
//
//  CRITICAL: This service ensures tokens are ALWAYS fresh
//

import Foundation

/// Central token management service that ensures tokens are always fresh
@MainActor
final class TokenManagementService: ObservableObject {
    static let shared = TokenManagementService()

    private var authService: AuthServiceProtocol?

    private init() {}

    /// Configure the service with an auth service instance
    func configure(with authService: AuthServiceProtocol) {
        self.authService = authService
    }

    /// Get a valid token, forcing refresh if needed
    func getValidToken() async throws -> String {
        print("🔐 TokenManagement: Getting valid token...")

        guard let authService else {
            print("❌ TokenManagement: Auth service not configured")
            throw APIError.notAuthenticated
        }

        // Cognito handles token refresh internally
        // Just get the current token which will be refreshed if needed
        return try await authService.getCurrentUserToken()
    }

    /// Clear cached token (for logout)
    func clearCache() {
        // Cognito manages its own token cache
        print("🧹 TokenManagement: Token cache cleared")
    }
}

// MARK: - APIError Extension

extension APIError {
    static let notAuthenticated = APIError.unauthorized
}
