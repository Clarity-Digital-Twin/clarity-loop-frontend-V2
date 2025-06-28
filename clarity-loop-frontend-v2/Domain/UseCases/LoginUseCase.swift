//
//  LoginUseCase.swift
//  clarity-loop-frontend-v2
//
//  Use case for user login
//

import Foundation

/// Result of a successful login
public struct LoginResult {
    public let user: User
    public let token: AuthToken
    
    public init(user: User, token: AuthToken) {
        self.user = user
        self.token = token
    }
}

/// Use case for handling user login
public final class LoginUseCase: LoginUseCaseProtocol, Sendable {
    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol
    
    public init(
        authService: AuthServiceProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    /// Executes the login process
    @MainActor
    public func execute(email: String, password: String) async throws -> User {
        // Validate input
        guard validateInput(email: email, password: password) else {
            throw AuthError.invalidCredentials
        }
        
        // Authenticate with the service
        _ = try await authService.login(email: email, password: password)
        
        // Get the authenticated user
        guard let user = try await authService.getCurrentUser() else {
            throw AuthError.unknown("Failed to retrieve user after login")
        }
        
        // Update last login time
        let updatedUser = user.withUpdatedLastLogin()
        _ = try await userRepository.update(updatedUser)
        
        return updatedUser
    }
    
    /// Validates login input
    public func validateInput(email: String, password: String) -> Bool {
        !email.isEmpty && !password.isEmpty
    }
}
