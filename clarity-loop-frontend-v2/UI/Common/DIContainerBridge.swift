//
//  DIContainerBridge.swift
//  clarity-loop-frontend-v2
//
//  TEMPORARY: Direct bridge to fix black screen immediately
//

import Foundation
import ClarityCore
import ClarityDomain
import ClarityData
import ClarityUI
import SwiftData

public struct DIContainerBridge {
    public static func configureDirectly() {
        print("🚀 DIContainerBridge: Starting direct configuration...")
        
        let container = DIContainer.shared
        let deps = Dependencies()
        
        // Configure Dependencies first
        let configurator = AppDependencyConfigurator()
        configurator.configure(deps)
        
        // Now manually mirror everything to DIContainer
        // This is a temporary fix until we migrate to pure Dependencies
        
        // Infrastructure
        container.register(NetworkServiceProtocol.self) { _ in
            MockNetworkService() // Use mock for now
        }
        
        container.register(KeychainServiceProtocol.self) { _ in
            KeychainService()
        }
        
        container.register(BiometricAuthServiceProtocol.self) { _ in
            BiometricAuthService()
        }
        
        container.register(TokenStorageProtocol.self) { resolver in
            KeychainTokenStorage(keychainService: resolver.require(KeychainServiceProtocol.self))
        }
        
        container.register(APIClientProtocol.self) { resolver in
            APIClient(
                networkService: resolver.require(NetworkServiceProtocol.self),
                tokenStorage: resolver.require(TokenStorageProtocol.self)
            )
        }
        
        // Model Container
        container.register(ModelContainerFactory.self) { _ in
            ModelContainerFactory()
        }
        
        container.register(ModelContainer.self) { resolver in
            let factory = resolver.require(ModelContainerFactory.self)
            return try! factory.createContainer()
        }
        
        container.register(PersistenceServiceProtocol.self) { resolver in
            SwiftDataPersistence(container: resolver.require(ModelContainer.self))
        }
        
        // Auth Service
        container.register(AuthServiceProtocol.self) { resolver in
            AmplifyAuthService(tokenStorage: resolver.require(TokenStorageProtocol.self))
        }
        
        // Repositories
        container.register(UserRepositoryProtocol.self) { resolver in
            UserRepository(
                apiClient: resolver.require(APIClientProtocol.self),
                persistenceService: resolver.require(PersistenceServiceProtocol.self)
            )
        }
        
        container.register(HealthMetricRepositoryProtocol.self) { resolver in
            HealthMetricRepository(
                apiClient: resolver.require(APIClientProtocol.self),
                persistenceService: resolver.require(PersistenceServiceProtocol.self)
            )
        }
        
        // Use Cases
        container.register(LoginUseCaseProtocol.self) { resolver in
            LoginUseCase(
                authService: resolver.require(AuthServiceProtocol.self),
                userRepository: resolver.require(UserRepositoryProtocol.self)
            )
        }
        
        // View Model Factories - CRITICAL for LoginView
        container.register(LoginViewModelFactory.self) { resolver in
            DefaultLoginViewModelFactory(
                loginUseCase: resolver.require(LoginUseCaseProtocol.self)
            )
        }
        
        container.register(DashboardViewModelFactory.self) { resolver in
            DefaultDashboardViewModelFactory(
                healthMetricRepository: resolver.require(HealthMetricRepositoryProtocol.self)
            )
        }
        
        print("✅ DIContainerBridge: Configured \(container.registrations.count) services")
    }
}