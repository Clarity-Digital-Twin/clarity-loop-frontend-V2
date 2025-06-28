//
//  TokenStorageProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for secure token storage
//

import Foundation
import ClarityDomain

/// Protocol for secure token storage operations
public protocol TokenStorageProtocol: Sendable {
    /// Saves an auth token securely
    func saveToken(_ token: AuthToken) async throws
    
    /// Retrieves the stored token if valid
    func getToken() async throws -> AuthToken?
    
    /// Gets just the access token if valid
    func getAccessToken() async throws -> String?
    
    /// Clears all stored tokens
    func clearToken() async throws
}