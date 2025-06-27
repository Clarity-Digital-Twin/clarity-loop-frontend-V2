//
//  AppDependencies+SwiftUI.swift
//  clarity-loop-frontend-v2
//
//  SwiftUI Environment-based dependency configuration
//

import Foundation
import SwiftUI
import SwiftData
import ClarityCore
import ClarityDomain
import ClarityData
@preconcurrency import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSPluginsCore

/// Configures app dependencies for SwiftUI Environment injection
public extension AppDependencyConfigurator {
    
    /// Configure all app dependencies in the Dependencies container
    func configure(_ container: Dependencies) {
        configureInfrastructure(container)
        configureDataLayer(container)
        configureDomainLayer(container)
        configureUILayer(container)
    }
    
    // MARK: - Infrastructure Configuration
    
    private func configureInfrastructure(_ container: Dependencies) {
        // Network Client
        container.register(APIClientProtocol.self) {
            NetworkClient(
                session: URLSession.shared,
                baseURL: URL(string: "https://clarity.novamindnyc.com")!
            )
        }
        
        // Model Container Factory
        container.register(ModelContainerFactory.self) {
            ModelContainerFactory()
        }
        
        // Model Container
        container.register(ModelContainer.self) { dependencies in
            let factory = dependencies.require(ModelContainerFactory.self)
            return try! factory.createContainer()
        }
        
        // Persistence
        container.register(PersistenceServiceProtocol.self) { dependencies in
            let modelContainer = dependencies.require(ModelContainer.self)
            return SwiftDataPersistence(container: modelContainer)
        }
        
        // AWS Amplify Configuration
        container.register(AmplifyConfigurable.self) {
            AmplifyConfiguration()
        }
    }
    
    // MARK: - Data Layer Configuration
    
    private func configureDataLayer(_ container: Dependencies) {
        // Auth Service - Use mock for now until Amplify is properly configured
        container.register(AuthServiceProtocol.self) {
            MockAuthService()
        }
        
        // User Repository
        container.register(UserRepositoryProtocol.self) { dependencies in
            UserRepositoryImplementation(
                apiClient: dependencies.require(APIClientProtocol.self),
                persistence: dependencies.require(PersistenceServiceProtocol.self)
            )
        }
        
        // Health Metric Repository
        container.register(HealthMetricRepositoryProtocol.self) { dependencies in
            HealthMetricRepositoryImplementation(
                apiClient: dependencies.require(APIClientProtocol.self),
                persistence: dependencies.require(PersistenceServiceProtocol.self)
            )
        }
    }
    
    // MARK: - Domain Layer Configuration
    
    private func configureDomainLayer(_ container: Dependencies) {
        // Login Use Case
        container.register(LoginUseCaseProtocol.self) { dependencies in
            LoginUseCase(
                authService: dependencies.require(AuthServiceProtocol.self),
                userRepository: dependencies.require(UserRepositoryProtocol.self)
            )
        }
        
        // Record Health Metric Use Case
        container.register(RecordHealthMetricUseCase.self) { dependencies in
            RecordHealthMetricUseCase(
                repository: dependencies.require(HealthMetricRepositoryProtocol.self)
            )
        }
    }
    
    // MARK: - UI Layer Configuration
    
    private func configureUILayer(_ container: Dependencies) {
        // View Model Factories can be registered here if needed
        // For now, ViewModels will be created with dependencies from environment
    }
}

// MARK: - Environment Injection Extension

public extension View {
    /// Inject all configured dependencies into the environment
    func configuredDependencies() -> some View {
        let dependencies = Dependencies()
        let configurator = AppDependencyConfigurator()
        configurator.configure(dependencies)
        
        return self
            .dependencies(dependencies)
            .authService(dependencies.require(AuthServiceProtocol.self))
            .userRepository(dependencies.require(UserRepositoryProtocol.self))
            .healthMetricRepository(dependencies.require(HealthMetricRepositoryProtocol.self))
            .apiClient(dependencies.require(APIClientProtocol.self))
            .persistenceService(dependencies.require(PersistenceServiceProtocol.self))
            .customModelContainer(dependencies.require(ModelContainer.self))
            .loginUseCase(dependencies.require(LoginUseCaseProtocol.self))
    }
}

// MARK: - Mock Auth Service

private struct MockAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> AuthToken {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock token
        return AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    func logout() async throws {
        // Mock logout
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        // Return mock user
        return User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        return AuthToken(
            accessToken: "mock-refreshed-access-token",
            refreshToken: "mock-refreshed-refresh-token",
            expiresIn: 3600
        )
    }
}

// MARK: - Amplify Configuration (moved from AppDependencies)

private protocol AmplifyConfigurable {
    func configure() async throws
}

private final class AmplifyConfiguration: AmplifyConfigurable {
    func configure() async throws {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
        } catch {
            print("Failed to configure Amplify: \(error)")
            throw error
        }
    }
}

// MARK: - Amplify Auth Service (moved from AppDependencies)

final class AmplifyAuthService: AuthServiceProtocol {
    
    func login(email: String, password: String) async throws -> AuthToken {
        let result = try await Amplify.Auth.signIn(username: email, password: password)
        
        guard result.isSignedIn else {
            throw AuthError.invalidCredentials
        }
        
        // Get session tokens from AWS Cognito
        let session = try await Amplify.Auth.fetchAuthSession()
        
        // Cast to AuthCognitoTokensProvider to get tokens
        guard let cognitoTokenProvider = session as? AuthCognitoTokensProvider else {
            throw AuthError.unknown("Failed to retrieve Cognito session")
        }
        
        // Get the user pool tokens
        let tokens = try cognitoTokenProvider.getCognitoTokens().get()
        
        return AuthToken(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: 3600 // AWS Cognito default
        )
    }
    
    func logout() async throws {
        _ = await Amplify.Auth.signOut()
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        // Force refresh the session
        let session = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
        
        // Cast to AuthCognitoTokensProvider to get tokens
        guard let cognitoTokenProvider = session as? AuthCognitoTokensProvider else {
            throw AuthError.unknown("Failed to retrieve Cognito session")
        }
        
        // Get the refreshed tokens
        do {
            let tokens = try cognitoTokenProvider.getCognitoTokens().get()
            return AuthToken(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: 3600 // AWS Cognito default
            )
        } catch {
            throw AuthError.tokenExpired
        }
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        let attributes = try await Amplify.Auth.fetchUserAttributes()
        
        var email: String?
        var firstName: String?
        var lastName: String?
        var userId: String?
        
        for attribute in attributes {
            switch attribute.key {
            case .email:
                email = attribute.value
            case .givenName:
                firstName = attribute.value
            case .familyName:
                lastName = attribute.value
            case .sub:
                userId = attribute.value
            default:
                break
            }
        }
        
        guard let email = email,
              let userId = userId,
              let uuid = UUID(uuidString: userId) else {
            return nil
        }
        
        return User(
            id: uuid,
            email: email,
            firstName: firstName ?? "",
            lastName: lastName ?? ""
        )
    }
}