//
//  AppDependencies+SwiftUI.swift
//  clarity-loop-frontend-v2
//
//  Created by Clarity on 2025-06-27.
//

import SwiftUI
import SwiftData
@preconcurrency import Amplify
@preconcurrency import AWSCognitoAuthPlugin
@preconcurrency import AWSAPIPlugin
@preconcurrency import AWSPluginsCore
import ClarityCore
import ClarityDomain
import ClarityData

// MARK: - SwiftUI App Dependencies

/// Configures all app dependencies for SwiftUI environment
public final class AppDependencyConfigurator {

    public init() {}

    public func configure(_ container: Dependencies) {
        print("🔧 AppDependencyConfigurator.configure() called")
        configureInfrastructure(container)
        print("✅ Infrastructure configured")
        configureDataLayer(container)
        print("✅ Data layer configured")
        configureDomainLayer(container)
        print("✅ Domain layer configured")
        configureUILayer(container)
        print("✅ UI layer configured")
        print("🚀 All dependencies configured successfully")
    }

    // MARK: - Infrastructure Configuration

    private func configureInfrastructure(_ container: Dependencies) {
        // Keychain Service (no dependencies)
        container.register(KeychainServiceProtocol.self) {
            KeychainService()
        }

        // Token Storage (depends on keychain only)
        container.register(TokenStorageProtocol.self) {
            TokenStorage(keychain: container.require(KeychainServiceProtocol.self))
        }

        // Biometric Auth Service (no dependencies)
        container.register(BiometricAuthServiceProtocol.self) {
            BiometricAuthService()
        }

        // Auth Service
        container.register(AuthServiceProtocol.self) {
            AmplifyAuthService()
        }

        // Network Service (now can depend on auth service)
        container.register(NetworkServiceProtocol.self) {
            NetworkService(
                baseURL: URL(string: "https://clarity.novamindnyc.com")!,
                authService: container.require(AuthServiceProtocol.self),
                tokenStorage: container.require(TokenStorageProtocol.self)
            )
        }

        // API Client - REAL implementation connected to backend!
        container.register(APIClientProtocol.self) {
            APIClient(networkService: container.require(NetworkServiceProtocol.self))
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
        // Register ViewModelFactories
        container.register(LoginViewModelFactory.self) { dependencies in
            DefaultLoginViewModelFactory(
                loginUseCase: dependencies.require(LoginUseCaseProtocol.self)
            )
        }

        container.register(DashboardViewModelFactory.self) { dependencies in
            DefaultDashboardViewModelFactory(
                healthMetricRepository: dependencies.require(HealthMetricRepositoryProtocol.self)
            )
        }
    }
}

// MARK: - SwiftUI Integration

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

// MARK: - Amplify Configuration

public protocol AmplifyConfigurable {
    func configure() async throws
}

public final class AmplifyConfiguration: AmplifyConfigurable, @unchecked Sendable {

    private var isAmplifyConfigured = false

    public init() {}

    nonisolated public func configure() async throws {
        print("🚀 [AmplifyConfiguration] Starting Amplify configuration...")
        print("🔍 [AmplifyConfiguration] Bundle path: \(Bundle.main.bundlePath)")

        do {
            // Step 1: Check if configuration file exists
            print("📁 [AmplifyConfiguration] Step 1: Checking for amplifyconfiguration.json...")
            guard let configPath = Bundle.main.path(forResource: "amplifyconfiguration", ofType: "json") else {
                let error = NSError(domain: "AmplifyConfiguration", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "amplifyconfiguration.json not found in bundle"
                ])
                print("❌ [AmplifyConfiguration] Configuration file not found")
                throw error
            }
            print("✅ [AmplifyConfiguration] Configuration file found at: \(configPath)")

            // Step 2: Validate configuration content
            print("🔐 [AmplifyConfiguration] Step 2: Validating configuration content...")
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            print("✅ [AmplifyConfiguration] Configuration data loaded: \(configData.count) bytes")

            // Step 3: Parse and validate JSON structure
            print("🌐 [AmplifyConfiguration] Step 3: Parsing configuration JSON...")
            if let configJson = try JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                print("✅ [AmplifyConfiguration] Configuration JSON parsed successfully")
                if configJson["auth"] != nil {
                    print("✅ [AmplifyConfiguration] Auth section found in config")
                }
                if configJson["api"] != nil {
                    print("✅ [AmplifyConfiguration] API section found in config")
                }
            }

            // Step 4: Check if Amplify is already configured
            print("⚙️ [AmplifyConfiguration] Step 4: Checking Amplify state...")
            if isAmplifyConfigured {
                print("✅ [AmplifyConfiguration] Amplify already configured")
                return
            }

            // Step 5: Configure Amplify with proper error handling
            print("🌐 [AmplifyConfiguration] Step 5: Adding Amplify plugins...")

            print("🔐 [AmplifyConfiguration] Adding AWSCognitoAuthPlugin...")
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            print("✅ [AmplifyConfiguration] AWSCognitoAuthPlugin added successfully")

            print("🌐 [AmplifyConfiguration] Adding AWSAPIPlugin...")
            try Amplify.add(plugin: AWSAPIPlugin())
            print("✅ [AmplifyConfiguration] AWSAPIPlugin added successfully")

            print("⚙️ [AmplifyConfiguration] Configuring Amplify with configuration file...")
            try Amplify.configure()
            print("✅ [AmplifyConfiguration] Amplify configured successfully!")

            // Step 6: Mark as configured
            print("🔍 [AmplifyConfiguration] Step 6: Marking Amplify as configured...")
            isAmplifyConfigured = true
            print("✅ [AmplifyConfiguration] Configuration state updated")

            print("🎉 [AmplifyConfiguration] All steps completed successfully!")

        } catch {
            print("💥 [AmplifyConfiguration] Configuration failed: \(error)")
            print("🚨 [AmplifyConfiguration] Error type: \(type(of: error))")
            print("🚨 [AmplifyConfiguration] Error description: \(error.localizedDescription)")

            // Enhanced error reporting for debugging
            if let nsError = error as NSError? {
                print("🚨 [AmplifyConfiguration] Error domain: \(nsError.domain)")
                print("🚨 [AmplifyConfiguration] Error code: \(nsError.code)")
                print("🚨 [AmplifyConfiguration] Error userInfo: \(nsError.userInfo)")
            }

            // Don't bypass - throw the error so we can fix it properly
            throw error
        }
    }
}

// MARK: - Timeout Helper

private struct TimeoutError: LocalizedError {
    let seconds: TimeInterval

    init(seconds: TimeInterval = 30) {
        self.seconds = seconds
    }

    var errorDescription: String? {
        return "Operation timed out after \(seconds) seconds"
    }
}
