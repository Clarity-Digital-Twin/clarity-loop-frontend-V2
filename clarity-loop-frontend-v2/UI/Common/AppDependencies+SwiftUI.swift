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
    var isConfigured: Bool { get }
    func reset() async throws
}

/// Singleton AmplifyConfiguration with robust error handling and timeout
public final class AmplifyConfiguration: AmplifyConfigurable, @unchecked Sendable {

    // MARK: - Singleton
    public static let shared = AmplifyConfiguration()

    // MARK: - State Management
    private var _isConfigured = false
    private let configurationLock = NSLock()
    private let configurationTimeout: TimeInterval = 15.0 // Reduced from 30s

    public var isConfigured: Bool {
        configurationLock.lock()
        defer { configurationLock.unlock() }
        return _isConfigured
    }

    private init() {
        print("🏗️ [AmplifyConfiguration] Singleton instance created")
    }

    // MARK: - Public Configuration Method
    nonisolated public func configure() async throws {
        print("🚀 [AmplifyConfiguration] GIVEN: Starting Amplify configuration process")

        // WHEN: Check if already configured
        if isConfigured {
            print("✅ [AmplifyConfiguration] THEN: Amplify already configured - skipping")
            return
        }

        // WHEN: Attempt configuration with timeout
        do {
            try await configureWithTimeout()
            print("🎉 [AmplifyConfiguration] THEN: Configuration completed successfully")
        } catch {
            print("💥 [AmplifyConfiguration] THEN: Configuration failed - \(error)")
            throw error
        }
    }

    // MARK: - Reset Method for Testing
    public func reset() async throws {
        print("🔄 [AmplifyConfiguration] GIVEN: Resetting Amplify configuration")

        configurationLock.lock()
        _isConfigured = false
        configurationLock.unlock()

        do {
            await Amplify.reset()
            print("✅ [AmplifyConfiguration] THEN: Amplify reset successfully")
        } catch {
            print("❌ [AmplifyConfiguration] THEN: Reset failed - \(error)")
            throw error
        }
    }

    // MARK: - Private Implementation
    private func configureWithTimeout() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in

            // Add configuration task
            group.addTask { [weak self] in
                try await self?.performConfiguration()
            }

            // Add timeout task
            group.addTask { [configurationTimeout] in
                try await Task.sleep(nanoseconds: UInt64(configurationTimeout * 1_000_000_000))
                throw AmplifyConfigurationError.timeout(configurationTimeout)
            }

            // Wait for first completion and cancel others
            try await group.next()
            group.cancelAll()
        }
    }

    private func performConfiguration() async throws {
        print("📋 [AmplifyConfiguration] WHEN: Starting configuration steps")

        // Step 1: Validate configuration file
        let configPath = try validateConfigurationFile()
        print("✅ [AmplifyConfiguration] THEN: Configuration file validated at \(configPath)")

        // Step 2: Add plugins safely
        try await addPluginsSafely()
        print("✅ [AmplifyConfiguration] THEN: Plugins added successfully")

        // Step 3: Configure Amplify
        try await configureAmplifyCore()
        print("✅ [AmplifyConfiguration] THEN: Amplify core configured")

        // Step 4: Mark as configured
        configurationLock.lock()
        _isConfigured = true
        configurationLock.unlock()
        print("✅ [AmplifyConfiguration] THEN: Configuration state updated")
    }

    private func validateConfigurationFile() throws -> String {
        print("📁 [AmplifyConfiguration] WHEN: Validating amplifyconfiguration.json")

        guard let configPath = Bundle.main.path(forResource: "amplifyconfiguration", ofType: "json") else {
            throw AmplifyConfigurationError.configurationFileNotFound
        }

        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            guard configData.count > 0 else {
                throw AmplifyConfigurationError.emptyConfigurationFile
            }

            // Validate JSON structure
            if let configJson = try JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                guard configJson["auth"] != nil else {
                    throw AmplifyConfigurationError.missingAuthConfiguration
                }
                print("✅ [AmplifyConfiguration] THEN: Configuration JSON validated (\(configData.count) bytes)")
            } else {
                throw AmplifyConfigurationError.invalidConfigurationFormat
            }

            return configPath
        } catch {
            if error is AmplifyConfigurationError {
                throw error
            } else {
                throw AmplifyConfigurationError.configurationReadError(error)
            }
        }
    }

    private func addPluginsSafely() async throws {
        print("🔌 [AmplifyConfiguration] WHEN: Adding Amplify plugins")

        do {
            // Only add plugins if not already added
            if !Amplify.Auth.plugins.contains(where: { $0.key == "awsCognitoAuthPlugin" }) {
                try Amplify.add(plugin: AWSCognitoAuthPlugin())
                print("✅ [AmplifyConfiguration] THEN: AWSCognitoAuthPlugin added")
            }

            if !Amplify.API.plugins.contains(where: { $0.key == "awsAPIPlugin" }) {
                try Amplify.add(plugin: AWSAPIPlugin())
                print("✅ [AmplifyConfiguration] THEN: AWSAPIPlugin added")
            }
        } catch {
            throw AmplifyConfigurationError.pluginError(error)
        }
    }

    private func configureAmplifyCore() async throws {
        print("⚙️ [AmplifyConfiguration] WHEN: Configuring Amplify core")

        do {
            try Amplify.configure()
            print("✅ [AmplifyConfiguration] THEN: Amplify core configured successfully")
        } catch {
            throw AmplifyConfigurationError.amplifyConfigurationError(error)
        }
    }
}

// MARK: - Amplify Configuration Errors
public enum AmplifyConfigurationError: LocalizedError, Equatable {
    case configurationFileNotFound
    case emptyConfigurationFile
    case missingAuthConfiguration
    case invalidConfigurationFormat
    case configurationReadError(Error)
    case pluginError(Error)
    case amplifyConfigurationError(Error)
    case timeout(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .configurationFileNotFound:
            return "amplifyconfiguration.json not found in app bundle"
        case .emptyConfigurationFile:
            return "Configuration file is empty"
        case .missingAuthConfiguration:
            return "Auth configuration missing from amplifyconfiguration.json"
        case .invalidConfigurationFormat:
            return "Invalid JSON format in configuration file"
        case .configurationReadError(let error):
            return "Failed to read configuration: \(error.localizedDescription)"
        case .pluginError(let error):
            return "Failed to add Amplify plugin: \(error.localizedDescription)"
        case .amplifyConfigurationError(let error):
            return "Amplify configuration failed: \(error.localizedDescription)"
        case .timeout(let seconds):
            return "Configuration timed out after \(seconds) seconds"
        }
    }

    public static func == (lhs: AmplifyConfigurationError, rhs: AmplifyConfigurationError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationFileNotFound, .configurationFileNotFound),
             (.emptyConfigurationFile, .emptyConfigurationFile),
             (.missingAuthConfiguration, .missingAuthConfiguration),
             (.invalidConfigurationFormat, .invalidConfigurationFormat):
            return true
        case (.timeout(let lhsSeconds), .timeout(let rhsSeconds)):
            return lhsSeconds == rhsSeconds
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
