//
//  AuthenticationService.swift
//  clarity-loop-frontend-v2
//
//  Authentication service following SwiftUI MV pattern
//

import SwiftUI
import ClarityCore
import ClarityDomain
import ClarityData

@Observable
@MainActor
public final class AuthenticationService {
    // MARK: - State
    public var isAuthenticated = false
    public var currentUser: User?
    public var isLoading = false
    public var error: Error?
    
    // MARK: - Dependencies
    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol
    
    public init(authService: AuthServiceProtocol, userRepository: UserRepositoryProtocol) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    public func login(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            // Authenticate with backend
            let authToken = try await authService.login(email: email, password: password)
            
            // Fetch user profile
            let user = try await userRepository.getCurrentUser()
            
            // Update state
            self.currentUser = user
            self.isAuthenticated = true
            
            print("✅ Login successful for user: \(user.email)")
        } catch {
            print("❌ Login failed: \(error)")
            self.error = error
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        isLoading = false
    }
    
    public func logout() async {
        isLoading = true
        
        do {
            try await authService.logout()
            
            // Clear state
            self.currentUser = nil
            self.isAuthenticated = false
            self.error = nil
            
            print("✅ Logout successful")
        } catch {
            print("❌ Logout failed: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    public func checkAuthStatus() async {
        isLoading = true
        
        do {
            let isValid = try await authService.isAuthenticated()
            
            if isValid {
                // Fetch current user
                let user = try await userRepository.getCurrentUser()
                self.currentUser = user
                self.isAuthenticated = true
            } else {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        } catch {
            print("❌ Auth check failed: \(error)")
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        isLoading = false
    }
    
    public func clearError() {
        error = nil
    }
}

// MARK: - Environment Key
private struct AuthenticationServiceKey: EnvironmentKey {
    static let defaultValue: AuthenticationService? = nil
}

public extension EnvironmentValues {
    var authenticationService: AuthenticationService? {
        get { self[AuthenticationServiceKey.self] }
        set { self[AuthenticationServiceKey.self] = newValue }
    }
}

// MARK: - View Extension
public extension View {
    func authenticationService(_ service: AuthenticationService?) -> some View {
        environment(\.authenticationService, service)
    }
}