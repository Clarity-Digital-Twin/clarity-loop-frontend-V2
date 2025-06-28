//
//  TokenStorage.swift
//  clarity-loop-frontend-v2
//
//  Secure token storage implementation
//

import Foundation
import ClarityDomain
import ClarityCore

/// Secure token storage using Keychain
public final class TokenStorage: TokenStorageProtocol {
    
    // MARK: - Constants
    
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let expiresAt = "auth.expiresAt"
    }
    
    // MARK: - Properties
    
    private let keychain: KeychainServiceProtocol
    
    // MARK: - Initialization
    
    public init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }
    
    // MARK: - TokenStorageProtocol
    
    public func saveToken(_ token: AuthToken) async throws {
        // Calculate expiration date
        let expiresAt = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        
        // Save all token components
        try keychain.save(token.accessToken, forKey: Keys.accessToken)
        try keychain.save(token.refreshToken, forKey: Keys.refreshToken)
        try keychain.save(String(expiresAt.timeIntervalSince1970), forKey: Keys.expiresAt)
    }
    
    public func getToken() async throws -> AuthToken? {
        // Try to retrieve all components
        guard let accessToken = try? keychain.retrieve(Keys.accessToken),
              let refreshToken = try? keychain.retrieve(Keys.refreshToken),
              let expiresAtString = try? keychain.retrieve(Keys.expiresAt),
              let expiresAtInterval = TimeInterval(expiresAtString) else {
            return nil
        }
        
        // Check if token is expired
        let expiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        if expiresAt <= Date() {
            // Token expired, clear it
            try? await clearToken()
            return nil
        }
        
        // Calculate remaining time
        let expiresIn = Int(expiresAt.timeIntervalSinceNow)
        
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )
    }
    
    public func getAccessToken() async throws -> String? {
        let token = try await getToken()
        return token?.accessToken
    }
    
    public func clearToken() async throws {
        // Delete all token components
        try keychain.delete(Keys.accessToken)
        try keychain.delete(Keys.refreshToken)
        try keychain.delete(Keys.expiresAt)
    }
}
