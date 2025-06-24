//
//  CognitoAuthService.swift
//  clarity-loop-frontend
//
//  Created by Claude on 6/10/2025.
//

import Foundation
import AuthenticationServices
import Combine

@MainActor
final class CognitoAuthService: NSObject {
    private var configuration = CognitoConfiguration.shared
    private var authSession: ASWebAuthenticationSession?
    
    // Store tokens
    private var accessToken: String?
    private var idToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?
    
    // Current user info
    private var userInfo: [String: Any]?
    
    // Publishers
    private let authStateSubject = PassthroughSubject<AuthUser?, Never>()
    var authStatePublisher: AnyPublisher<AuthUser?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        Task {
            await discoverConfiguration()
        }
    }
    
    // MARK: - OIDC Discovery
    
    private func discoverConfiguration() async {
        guard let discoveryURL = configuration.discoveryURL else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: discoveryURL)
            let discovery = try JSONDecoder().decode(OIDCDiscoveryDocument.self, from: data)
            
            configuration.authorizationEndpoint = URL(string: discovery.authorizationEndpoint)
            configuration.tokenEndpoint = URL(string: discovery.tokenEndpoint)
            configuration.userInfoEndpoint = URL(string: discovery.userinfoEndpoint)
            configuration.endSessionEndpoint = URL(string: discovery.endSessionEndpoint)
        } catch {
            print("Failed to discover OIDC configuration: \(error)")
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        // For native login, we'll use the authorization code flow
        // This initiates the web-based login
        return try await performAuthorizationCodeFlow()
    }
    
    func signUp(email: String, password: String, fullName: String) async throws -> AuthUser {
        // Registration will also use the authorization code flow
        // Cognito will handle the signup flow in the hosted UI
        return try await performAuthorizationCodeFlow()
    }
    
    func signOut() async throws {
        defer {
            // Clear local auth state
            accessToken = nil
            idToken = nil
            refreshToken = nil
            tokenExpirationDate = nil
            userInfo = nil
            authStateSubject.send(nil)
        }
        
        // Perform logout with Cognito
        guard let endSessionEndpoint = configuration.endSessionEndpoint else {
            throw AuthError.configurationError
        }
        
        guard var components = URLComponents(url: endSessionEndpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.configurationError
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "logout_uri", value: configuration.logoutURI)
        ]
        
        guard let logoutURL = components.url else {
            throw AuthError.configurationError
        }
        
        // Open logout URL
        await UIApplication.shared.open(logoutURL)
    }
    
    func getCurrentUser() async throws -> AuthUser? {
        guard accessToken != nil, let userInfo = userInfo else {
            return nil
        }
        
        // Check if token is expired
        if let expirationDate = tokenExpirationDate, Date() >= expirationDate {
            // Token expired, try to refresh
            if let refreshToken = refreshToken {
                try await refreshAccessToken(refreshToken: refreshToken)
            } else {
                return nil
            }
        }
        
        return createAuthUser(from: userInfo)
    }
    
    func getIDToken() async throws -> String {
        guard let token = idToken else {
            throw AuthError.notAuthenticated
        }
        
        // Check if token needs refresh
        if let expirationDate = tokenExpirationDate, Date() >= expirationDate {
            if let refreshToken = refreshToken {
                try await refreshAccessToken(refreshToken: refreshToken)
                return idToken ?? ""
            }
        }
        
        return token
    }
    
    // MARK: - Authorization Code Flow
    
    private func performAuthorizationCodeFlow() async throws -> AuthUser {
        guard let authEndpoint = configuration.authorizationEndpoint else {
            throw AuthError.configurationError
        }
        
        // Build authorization URL
        guard var components = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.configurationError
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: generateCodeChallenge())
        ]
        
        guard let authURL = components.url else {
            throw AuthError.configurationError
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "clarityai"
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: AuthError.authenticationFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                            .queryItems?
                            .first(where: { $0.name == "code" })?
                            .value else {
                        continuation.resume(throwing: AuthError.authenticationFailed("No authorization code received"))
                        return
                    }
                    
                    do {
                        // Exchange code for tokens
                        let tokens = try await self?.exchangeCodeForTokens(code: code) ?? TokenResponse(accessToken: "", idToken: "", refreshToken: nil, expiresIn: 0)
                        
                        // Store tokens
                        self?.accessToken = tokens.accessToken
                        self?.idToken = tokens.idToken
                        self?.refreshToken = tokens.refreshToken
                        self?.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
                        
                        // Fetch user info
                        let userInfo = try await self?.fetchUserInfo() ?? [:]
                        self?.userInfo = userInfo
                        
                        let authUser = self?.createAuthUser(from: userInfo) ?? AuthUser(id: "", email: "", fullName: nil, isEmailVerified: true)
                        self?.authStateSubject.send(authUser)
                        
                        continuation.resume(returning: authUser)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authSession?.presentationContextProvider = self
            authSession?.start()
        }
    }
    
    // MARK: - Token Management
    
    private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
        guard let tokenEndpoint = configuration.tokenEndpoint else {
            throw AuthError.configurationError
        }
        
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "client_id": configuration.clientID,
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    private func refreshAccessToken(refreshToken: String) async throws {
        guard let tokenEndpoint = configuration.tokenEndpoint else {
            throw AuthError.configurationError
        }
        
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "refresh_token",
            "client_id": configuration.clientID,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Update stored tokens
        self.accessToken = tokens.accessToken
        self.idToken = tokens.idToken
        if let newRefreshToken = tokens.refreshToken {
            self.refreshToken = newRefreshToken
        }
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
    }
    
    private func fetchUserInfo() async throws -> [String: Any] {
        guard let userInfoEndpoint = configuration.userInfoEndpoint,
              let accessToken = accessToken else {
            throw AuthError.configurationError
        }
        
        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        return json
    }
    
    // MARK: - Helpers
    
    private func createAuthUser(from userInfo: [String: Any]) -> AuthUser {
        let id = userInfo["sub"] as? String ?? ""
        let email = userInfo["email"] as? String ?? ""
        let fullName = userInfo["name"] as? String
        let isEmailVerified = userInfo["email_verified"] as? Bool ?? false
        
        return AuthUser(
            id: id,
            email: email,
            fullName: fullName,
            isEmailVerified: isEmailVerified
        )
    }
    
    // MARK: - PKCE
    
    private let codeVerifier = generateCodeVerifier()
    
    private static func generateCodeVerifier() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge() -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            // This should never happen with valid ASCII characters
            return ""
        }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension CognitoAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - Supporting Types

private struct OIDCDiscoveryDocument: Codable {
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let userinfoEndpoint: String
    let endSessionEndpoint: String
    
    enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private enum AuthError: LocalizedError {
    case configurationError
    case authenticationFailed(String)
    case notAuthenticated
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Authentication configuration error"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - SHA256 Helper

import CryptoKit

private enum SHA256 {
    static func hash(data: Data) -> SHA256Digest {
        return CryptoKit.SHA256.hash(data: data)
    }
}