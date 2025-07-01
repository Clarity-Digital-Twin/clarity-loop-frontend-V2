//
//  LegacyDIConfiguration.swift
//  clarity-loop-frontend-v2
//
//  Direct configuration for legacy DIContainer to fix black screen
//

import Foundation
import ClarityCore
import ClarityDomain
import ClarityData

public enum LegacyDIConfiguration {
    
    public static func configure() {
        print("🔧 LegacyDIConfiguration: Starting direct DIContainer configuration")
        
        let container = DIContainer.shared
        
        // Create all dependencies manually
        let keychain = KeychainService()
        let biometric = BiometricAuthService()
        let tokenStorage = TokenStorage(keychain: keychain)
        let authService = AmplifyAuthService(tokenStorage: tokenStorage)
        let networkService = NetworkService(
            baseURL: URL(string: "https://clarity.novamindnyc.com")!,
            authService: authService,
            tokenStorage: tokenStorage
        )
        let apiClient = APIClient(networkService: networkService)
        
        // Create repositories
        let modelContainer = try! ModelContainerFactory().createContainer()
        let persistence = SwiftDataPersistence(container: modelContainer)
        let userRepository = UserRepositoryImplementation(
            apiClient: apiClient,
            persistence: persistence
        )
        let healthMetricRepository = HealthMetricRepositoryImplementation(
            apiClient: apiClient,
            persistence: persistence
        )
        
        // Create use cases
        let loginUseCase = LoginUseCase(
            authService: authService,
            userRepository: userRepository
        )
        
        // Register ViewModelFactory that LoginView needs
        container.register(LoginViewModelFactory.self) { _ in
            DefaultLoginViewModelFactory(loginUseCase: loginUseCase)
        }
        
        container.register(DashboardViewModelFactory.self) { _ in
            DefaultDashboardViewModelFactory(healthMetricRepository: healthMetricRepository)
        }
        
        print("✅ LegacyDIConfiguration: DIContainer configured with \(container.registrations.count) registrations")
    }
}