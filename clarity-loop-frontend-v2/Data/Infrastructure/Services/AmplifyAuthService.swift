//
//  AmplifyAuthService.swift
//  ClarityData
//
//  Real Amplify authentication service implementation using AWS Cognito
//

import Foundation
@preconcurrency import Amplify
@preconcurrency import AWSCognitoAuthPlugin
@preconcurrency import AWSPluginsCore
import ClarityDomain

/// Real implementation of AuthServiceProtocol using AWS Amplify/Cognito
public final class AmplifyAuthService: AuthServiceProtocol, @unchecked Sendable {

    public init() {}
    
    // MARK: - Private Helper
    
    private func ensureAmplifyConfigured() async throws {
        // Check if Amplify is configured
        do {
            _ = try await Amplify.Auth.fetchAuthSession()
            // If we get here, Amplify is configured
        } catch {
            // If Amplify is not configured, we can't authenticate
            print("⚠️ AmplifyAuthService: Amplify not configured - operating in offline mode")
            throw ClarityDomain.AuthError.unknown("Authentication service not available - offline mode")
        }
    }

    // MARK: - AuthServiceProtocol Implementation

    public func login(email: String, password: String) async throws -> AuthToken {
        do {
            // Ensure Amplify is configured
            try await ensureAmplifyConfigured()
            
            print("🔐 AmplifyAuthService: Attempting login for \(email)")

            // Use Amplify to sign in
            let signInResult = try await Amplify.Auth.signIn(
                username: email,
                password: password
            )

            print("✅ AmplifyAuthService: Sign in result - isSignedIn: \(signInResult.isSignedIn)")

            // Get the current session to extract tokens
            let session = try await Amplify.Auth.fetchAuthSession()

            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                print("❌ AmplifyAuthService: Failed to get Cognito session")
                throw ClarityDomain.AuthError.unknown("Failed to get authentication session")
            }

            let tokens = try cognitoSession.getCognitoTokens().get()

            print("✅ AmplifyAuthService: Successfully retrieved tokens")

            return AuthToken(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: 3600 // 1 hour default
            )

        } catch let error as ClarityDomain.AuthError {
            print("❌ AmplifyAuthService: Auth error - \(error)")
            throw error
        } catch {
            print("❌ AmplifyAuthService: Login failed - \(error)")

            // Map Amplify errors to our AuthError types based on error description
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("unauthorized") || errorDescription.contains("invalid") {
                throw ClarityDomain.AuthError.invalidCredentials
            } else if errorDescription.contains("network") {
                throw ClarityDomain.AuthError.networkError
            } else {
                throw ClarityDomain.AuthError.unknown(error.localizedDescription)
            }
        }
    }

    public func logout() async throws {
        // Ensure Amplify is configured
        try await ensureAmplifyConfigured()
        
        print("🔐 AmplifyAuthService: Attempting logout")
        _ = await Amplify.Auth.signOut()
        print("✅ AmplifyAuthService: Successfully logged out")
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        do {
            // Ensure Amplify is configured
            try await ensureAmplifyConfigured()
            
            print("🔐 AmplifyAuthService: Attempting token refresh")

            // Amplify handles token refresh automatically, so we just fetch the current session
            let session = try await Amplify.Auth.fetchAuthSession()

            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                throw ClarityDomain.AuthError.refreshFailed
            }

            let tokens = try cognitoSession.getCognitoTokens().get()

            print("✅ AmplifyAuthService: Successfully refreshed tokens")

            return AuthToken(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: 3600 // 1 hour default
            )

        } catch {
            print("❌ AmplifyAuthService: Token refresh failed - \(error)")
            throw ClarityDomain.AuthError.refreshFailed
        }
    }

    @MainActor
    public func getCurrentUser() async throws -> User? {
        do {
            // Ensure Amplify is configured
            try await ensureAmplifyConfigured()
            
            print("🔐 AmplifyAuthService: Attempting to get current user")

            let authUser = try await Amplify.Auth.getCurrentUser()

            // Get user attributes to build the User domain entity
            let attributes = try await Amplify.Auth.fetchUserAttributes()

            let email = attributes.first { $0.key == .email }?.value ?? authUser.username
            let firstName = attributes.first { $0.key == .givenName }?.value ?? ""
            let lastName = attributes.first { $0.key == .familyName }?.value ?? ""
            let phoneNumber = attributes.first { $0.key == .phoneNumber }?.value

            // Parse date of birth if available
            var dateOfBirth: Date?
            if let birthDateAttr = attributes.first(where: { $0.key.rawValue == "birthdate" }),
               !birthDateAttr.value.isEmpty {
                let formatter = ISO8601DateFormatter()
                dateOfBirth = formatter.date(from: birthDateAttr.value)
            }

            print("✅ AmplifyAuthService: Successfully retrieved current user - \(email)")

            return User(
                id: UUID(), // We'll use Cognito sub as ID in production
                email: email,
                firstName: firstName,
                lastName: lastName,
                createdAt: Date(), // Would get from user attributes in production
                updatedAt: Date(),
                lastLoginAt: Date(),
                dateOfBirth: dateOfBirth,
                phoneNumber: phoneNumber
            )

        } catch {
            print("❌ AmplifyAuthService: Get current user failed - \(error)")

            // If user is not authenticated, return nil instead of throwing
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("signed out") || errorDescription.contains("not authenticated") {
                return nil
            }

            throw ClarityDomain.AuthError.unknown(error.localizedDescription)
        }
    }
}
