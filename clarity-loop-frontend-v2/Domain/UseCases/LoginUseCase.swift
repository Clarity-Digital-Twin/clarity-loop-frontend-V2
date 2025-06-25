//
//  LoginUseCase.swift
//  clarity-loop-frontend-v2
//
//  Use case for user login
//

import Foundation

/// Result of a successful login
struct LoginResult {
    let user: User
    let token: AuthToken
}

/// Use case for handling user login
final class LoginUseCase: Sendable {
    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol
    
    init(
        authService: AuthServiceProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    /// Executes the login process
    func execute(email: String, password: String) async throws -> LoginResult {
        // Validate input
        guard validateInput(email: email, password: password) else {
            throw AuthError.invalidCredentials
        }
        
        // Authenticate with the service
        let token = try await authService.login(email: email, password: password)
        
        // Get the authenticated user
        guard let user = try await authService.getCurrentUser() else {
            throw AuthError.unknown("Failed to retrieve user after login")
        }
        
        // Update last login time
        user.updateLastLogin()
        _ = try await userRepository.update(user)
        
        return LoginResult(user: user, token: token)
    }
    
    /// Validates login input
    func validateInput(email: String, password: String) -> Bool {
        !email.isEmpty && !password.isEmpty
    }
}