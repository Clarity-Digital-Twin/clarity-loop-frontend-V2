//
//  AuthServiceProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for authentication service
//

import Foundation

/// Authentication token containing access credentials
struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

/// Authentication errors
enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case tokenExpired
    case refreshFailed
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .tokenExpired:
            return "Your session has expired"
        case .refreshFailed:
            return "Failed to refresh authentication"
        case .networkError:
            return "Network connection error"
        case .unknown(let message):
            return message
        }
    }
}

/// Protocol for authentication operations
protocol AuthServiceProtocol: Sendable {
    /// Authenticates user with email and password
    func login(email: String, password: String) async throws -> AuthToken
    
    /// Logs out the current user
    func logout() async throws
    
    /// Refreshes the authentication token
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    
    /// Gets the current authenticated user
    func getCurrentUser() async throws -> User?
}