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

        // AWS Amplify Configuration - Singleton
        container.register(AmplifyConfigurable.self) {
            AmplifyConfiguration.shared
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
    var isConfigured: Bool { get async }
    func reset() async throws
}

/// Singleton AmplifyConfiguration with robust error handling and timeout
public final class AmplifyConfiguration: AmplifyConfigurable, @unchecked Sendable {

    // MARK: - Singleton
    public static let shared = AmplifyConfiguration()

    // MARK: - State Management
    private let configurationActor = ConfigurationActor()
    private let configurationTimeout: TimeInterval = 15.0

    public var isConfigured: Bool {
        get async {
            await configurationActor.isConfigured
        }
    }

    private init() {
        print("🏗️ [AmplifyConfiguration] Singleton instance created")
    }

    // MARK: - Configuration Methods

    public func configure() async throws {
        print("🚀 [AmplifyConfiguration] GIVEN: Starting Amplify configuration process")

        let isAlreadyConfigured = await configurationActor.isConfigured
        if isAlreadyConfigured {
            print("✅ [AmplifyConfiguration] THEN: Already configured, skipping")
            return
        }

        // Timeout protection
        try await withTimeout(seconds: configurationTimeout) {
            try await self.performConfiguration()
        }
    }

    public func reset() async throws {
        print("🔄 [AmplifyConfiguration] GIVEN: Resetting Amplify configuration")

        await configurationActor.setConfigured(false)

        // Since Amplify.reset() is internal, we'll work around it
        print("⚠️ [AmplifyConfiguration] Note: Amplify reset requires app restart for full effect")
    }

    // MARK: - Private Implementation

    private func performConfiguration() async throws {
        print("🔧 [AmplifyConfiguration] WHEN: Performing Amplify configuration steps")

        // Step 1: Add plugins
        try await addPlugins()

        // Step 2: Configure Amplify
        try await configureAmplify()

        // Step 3: Validate configuration
        try await validateConfiguration()

        // Step 4: Mark as configured
        await configurationActor.setConfigured(true)
        print("✅ [AmplifyConfiguration] THEN: Configuration state updated")
    }

    private func addPlugins() async throws {
        print("🔌 [AmplifyConfiguration] WHEN: Adding Amplify plugins...")

        do {
            // Add plugins without checking for duplicates (Amplify handles this internally)
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            print("✅ [AmplifyConfiguration] THEN: AWSCognitoAuthPlugin added")

            try Amplify.add(plugin: AWSAPIPlugin())
            print("✅ [AmplifyConfiguration] THEN: AWSAPIPlugin added")

        } catch {
            if error.localizedDescription.contains("Plugin has already been added") {
                print("ℹ️ [AmplifyConfiguration] Plugins already added, continuing...")
            } else {
                print("❌ [AmplifyConfiguration] Failed to add plugins: \(error)")
                throw AmplifyConfigurationError.pluginSetupFailed(error)
            }
        }
    }

        private func configureAmplify() async throws {
        print("⚙️ [AmplifyConfiguration] WHEN: Configuring Amplify with configuration file...")

        do {
            try Amplify.configure()
            print("✅ [AmplifyConfiguration] THEN: Amplify configured successfully")
        } catch {
            print("❌ [AmplifyConfiguration] Amplify configuration failed: \(error)")
            throw AmplifyConfigurationError.configurationFailed(error)
        }
    }

    private func validateConfiguration() async throws {
        print("🔍 [AmplifyConfiguration] WHEN: Validating Amplify configuration...")

        do {
            // Test if configuration is working by checking auth status
            _ = try await Amplify.Auth.fetchAuthSession()
            print("✅ [AmplifyConfiguration] THEN: Configuration validation successful")
        } catch {
            print("⚠️ [AmplifyConfiguration] Configuration validation warning: \(error)")
            // Don't throw here as this might just mean user isn't signed in
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the operation task
            group.addTask {
                try await operation()
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AmplifyConfigurationError.timeout(Int(seconds))
            }

            // Return the first completed task result
            guard let result = try await group.next() else {
                throw AmplifyConfigurationError.timeout(Int(seconds))
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - Configuration Actor for Thread Safety

private actor ConfigurationActor {
    private var _isConfigured = false

    var isConfigured: Bool {
        _isConfigured
    }

    func setConfigured(_ configured: Bool) {
        _isConfigured = configured
    }
}

// MARK: - Error Types

public enum AmplifyConfigurationError: LocalizedError, Equatable {
    case timeout(Int)
    case configurationMissing
    case configurationFailed(Error)
    case pluginSetupFailed(Error)
    case validationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Amplify configuration timed out after \(seconds) seconds. " +
                   "You can skip AWS setup and continue with local features."
        case .configurationMissing:
            return "Amplify configuration file (amplifyconfiguration.json) is missing or invalid."
        case .configurationFailed(let error):
            return "Amplify configuration failed: \(error.localizedDescription)"
        case .pluginSetupFailed(let error):
            return "Failed to set up Amplify plugins: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Amplify configuration validation failed: \(message)"
        }
    }

    public static func == (lhs: AmplifyConfigurationError, rhs: AmplifyConfigurationError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout(let lhsSeconds), .timeout(let rhsSeconds)):
            return lhsSeconds == rhsSeconds
        case (.configurationMissing, .configurationMissing):
            return true
        case (.validationFailed(let lhsMessage), .validationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
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
