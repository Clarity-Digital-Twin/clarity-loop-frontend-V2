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
        // Network Client - register as APIClientProtocol since that's what repositories expect
        container.register(APIClientProtocol.self, scope: .singleton) { _ in
            NetworkClient(
                session: URLSession.shared,
                baseURL: URL(string: "https://api.clarity-pulse.com")!
            )
        }
        
        // Persistence
        container.register(PersistenceServiceProtocol.self, scope: .singleton) { _ in
            let modelContainer = try! ModelContainer(for: PersistedUser.self, PersistedHealthMetric.self)
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
            AmplifyAuthService()
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
            DashboardViewModelFactory { user in
                // MainActor is handled at the view level when creating the view model
                return DashboardViewModel(
                    user: user,
                    healthMetricRepository: container.require(HealthMetricRepositoryProtocol.self)
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
    public let create: (User) -> DashboardViewModel
    
    public init(create: @escaping (User) -> DashboardViewModel) {
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
    
    func login(email: String, password: String) async throws -> AuthToken {
        let result = try await Amplify.Auth.signIn(username: email, password: password)
        
        guard result.isSignedIn else {
            throw AuthError.invalidCredentials
        }
        
        // Get session tokens
        let session = try await Amplify.Auth.fetchAuthSession()
        
        guard let cognitoTokens = (session as? AuthCognitoTokensProvider)?.getCognitoTokens().get() else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Cognito tokens"])
        }
        
        return AuthToken(
            accessToken: cognitoTokens.accessToken,
            refreshToken: cognitoTokens.refreshToken,
            expiresIn: Int(cognitoTokens.expiration.timeIntervalSinceNow)
        )
    }
    
    func logout() async throws {
        _ = try await Amplify.Auth.signOut()
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        let session = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
        
        guard let cognitoTokens = (session as? AuthCognitoTokensProvider)?.getCognitoTokens().get() else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Cognito tokens"])
        }
        
        return AuthToken(
            accessToken: cognitoTokens.accessToken,
            refreshToken: cognitoTokens.refreshToken,
            expiresIn: Int(cognitoTokens.expiration.timeIntervalSinceNow)
        )
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