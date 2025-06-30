//
//  AppDependencies.swift
//  clarity-loop-frontend-v2
//
//  Registers all app dependencies with the DI container
//

import Foundation
import SwiftData
import ClarityCore
import ClarityDomain
import ClarityData
import ClarityUI
@preconcurrency import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSPluginsCore

// Import persistence models - they're in the same module
// No need for explicit imports since PersistedUser and PersistedHealthMetric
// are in the ClarityData module which is already imported

/// Main app dependency configuration
public final class AppDependencies {
    
    private let container: DIContainer
    
    public init(container: DIContainer = .shared) {
        self.container = container
    }
    
    /// Configure all app dependencies
    public func configure() {
        configureInfrastructure()
        configureDataLayer()
        configureDomainLayer()
        configureUILayer()
    }
    
    // MARK: - Infrastructure Configuration
    
    private func configureInfrastructure() {
        // App Configuration
        container.register(AppConfiguration.self, scope: .singleton) { _ in
            AppConfiguration.load()
        }
        
        // Network Service
        container.register(NetworkServiceProtocol.self, scope: .singleton) { container in
            let config = container.require(AppConfiguration.self)
            return NetworkService(
                baseURL: config.apiBaseURL,
                authService: container.require(AuthServiceProtocol.self),
                tokenStorage: container.require(TokenStorageProtocol.self)
            )
        }
        
        // API Client - REAL implementation connected to backend!
        container.register(APIClientProtocol.self, scope: .singleton) { container in
            APIClient(networkService: container.require(NetworkServiceProtocol.self))
        }
        
        // API Client concrete type (for AddMetricViewModel)
        container.register(APIClient.self, scope: .singleton) { container in
            APIClient(networkService: container.require(NetworkServiceProtocol.self))
        }
        
        // Keychain Service
        container.register(KeychainServiceProtocol.self, scope: .singleton) { _ in
            KeychainService()
        }
        
        // Biometric Auth Service
        container.register(BiometricAuthServiceProtocol.self, scope: .singleton) { _ in
            BiometricAuthService()
        }
        
        // Secure Storage for encrypted health data
        container.register(SecureStorageProtocol.self, scope: .singleton) { _ in
            SecureStorage()
        }
        
        // Token Storage
        container.register(TokenStorageProtocol.self, scope: .singleton) { container in
            TokenStorage(keychain: container.require(KeychainServiceProtocol.self))
        }
        
        // Model Container Factory
        container.register(ModelContainerFactory.self, scope: .singleton) { _ in
            ModelContainerFactory()
        }
        
        // Model Container
        container.register(ModelContainer.self, scope: .singleton) { container in
            let factory = container.require(ModelContainerFactory.self)
            do {
                return try factory.createContainer()
            } catch {
                // Log error and provide fallback
                print("⚠️ Failed to create ModelContainer: \(error)")
                print("Creating in-memory container as fallback")
                
                // Create in-memory container as fallback
                let schema = Schema([
                    PersistedUser.self,
                    PersistedHealthMetric.self
                ])
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    // This is a critical error - the app cannot function without a model container
                    preconditionFailure(
                        """
                        Failed to create ModelContainer: \(error)
                        This is a critical error. Please check:
                        1. SwiftData schema is valid
                        2. Device has sufficient storage
                        3. App has necessary permissions
                        """
                    )
                }
            }
        }
        
        // Persistence
        container.register(PersistenceServiceProtocol.self, scope: .singleton) { container in
            let modelContainer = container.require(ModelContainer.self)
            return SwiftDataPersistence(container: modelContainer)
        }
        
        // AWS Amplify Configuration
        container.register(AmplifyConfigurable.self, scope: .singleton) { _ in
            AmplifyConfiguration()
        }
    }
    
    // MARK: - Data Layer Configuration
    
    private func configureDataLayer() {
        // Auth Service
        container.register(AuthServiceProtocol.self, scope: .singleton) { container in
            AmplifyAuthService(
                tokenStorage: container.require(TokenStorageProtocol.self)
            )
        }
        
        // User Repository
        container.register(UserRepositoryProtocol.self, scope: .singleton) { container in
            UserRepositoryImplementation(
                apiClient: container.require(APIClientProtocol.self),
                persistence: container.require(PersistenceServiceProtocol.self)
            )
        }
        
        // Health Metric Repository
        container.register(HealthMetricRepositoryProtocol.self, scope: .singleton) { container in
            HealthMetricRepositoryImplementation(
                apiClient: container.require(APIClientProtocol.self),
                persistence: container.require(PersistenceServiceProtocol.self)
            )
        }
    }
    
    // MARK: - Domain Layer Configuration
    
    private func configureDomainLayer() {
        // Login Use Case
        container.register(LoginUseCaseProtocol.self, scope: .transient) { container in
            LoginUseCase(
                authService: container.require(AuthServiceProtocol.self),
                userRepository: container.require(UserRepositoryProtocol.self)
            )
        }
        
        // Record Health Metric Use Case
        container.register(RecordHealthMetricUseCase.self, scope: .transient) { container in
            RecordHealthMetricUseCase(
                repository: container.require(HealthMetricRepositoryProtocol.self)
            )
        }
    }
    
    // MARK: - UI Layer Configuration
    
    private func configureUILayer() {
        // View Model Factories
        container.register(LoginViewModelFactory.self, scope: .singleton) { container in
            LoginViewModelFactory { container.require(LoginUseCaseProtocol.self) }
        }
        
        container.register(DashboardViewModelFactory.self, scope: .singleton) { container in
            let repository = container.require(HealthMetricRepositoryProtocol.self)
            return DashboardViewModelFactory { @MainActor user in
                DashboardViewModel(
                    user: user,
                    healthMetricRepository: repository
                )
            }
        }
    }
}

// MARK: - Factory Types

public struct LoginViewModelFactory {
    public let create: () -> LoginUseCaseProtocol
    
    public init(create: @escaping () -> LoginUseCaseProtocol) {
        self.create = create
    }
}

public struct DashboardViewModelFactory {
    public let create: @MainActor (User) -> DashboardViewModel
    
    public init(create: @escaping @MainActor (User) -> DashboardViewModel) {
        self.create = create
    }
}

// MARK: - Amplify Configuration

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

// MARK: - Amplify Auth Service

private final class AmplifyAuthService: AuthServiceProtocol {
    
    private let tokenStorage: TokenStorageProtocol
    
    init(tokenStorage: TokenStorageProtocol) {
        self.tokenStorage = tokenStorage
    }
    
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
        
        // Default to 1 hour expiration (in seconds)
        let expiresIn: Int = 3600
        
        let authToken = AuthToken(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: expiresIn
        )
        
        // Store the token
        try await tokenStorage.saveToken(authToken)
        
        return authToken
    }
    
    func logout() async throws {
        _ = await Amplify.Auth.signOut()
        try await tokenStorage.clearToken()
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
            let expiresIn: Int = 3600 // Default to 1 hour
            
            return AuthToken(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: expiresIn
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
