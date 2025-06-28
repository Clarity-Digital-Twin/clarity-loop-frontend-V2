//
//  EnvironmentKeys.swift
//  clarity-loop-frontend-v2
//
//  SwiftUI Environment keys for dependency injection
//

import SwiftUI
import SwiftData
import ClarityDomain
import ClarityData

// MARK: - Auth Service Key

public struct AuthServiceKey: EnvironmentKey {
    public static let defaultValue: AuthServiceProtocol? = nil
}

public extension EnvironmentValues {
    var authService: AuthServiceProtocol? {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// MARK: - User Repository Key

public struct UserRepositoryKey: EnvironmentKey {
    public static let defaultValue: UserRepositoryProtocol? = nil
}

public extension EnvironmentValues {
    var userRepository: UserRepositoryProtocol? {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// MARK: - Health Metric Repository Key

public struct HealthMetricRepositoryKey: EnvironmentKey {
    public static let defaultValue: HealthMetricRepositoryProtocol? = nil
}

public extension EnvironmentValues {
    var healthMetricRepository: HealthMetricRepositoryProtocol? {
        get { self[HealthMetricRepositoryKey.self] }
        set { self[HealthMetricRepositoryKey.self] = newValue }
    }
}

// MARK: - API Client Key

public struct APIClientKey: EnvironmentKey {
    public static let defaultValue: APIClientProtocol? = nil
}

public extension EnvironmentValues {
    var apiClient: APIClientProtocol? {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// MARK: - Persistence Service Key

public struct PersistenceServiceKey: EnvironmentKey {
    public static let defaultValue: PersistenceServiceProtocol? = nil
}

public extension EnvironmentValues {
    var persistenceService: PersistenceServiceProtocol? {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
}

// MARK: - Model Container Key

public struct ModelContainerKey: EnvironmentKey {
    public static let defaultValue: ModelContainer? = nil
}

public extension EnvironmentValues {
    var modelContainer: ModelContainer? {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}

// MARK: - Login Use Case Key

public struct LoginUseCaseKey: EnvironmentKey {
    public static let defaultValue: LoginUseCaseProtocol? = nil
}

public extension EnvironmentValues {
    var loginUseCase: LoginUseCaseProtocol? {
        get { self[LoginUseCaseKey.self] }
        set { self[LoginUseCaseKey.self] = newValue }
    }
}

// MARK: - View Extension for Service Injection

public extension View {
    /// Inject auth service into the environment
    func authService(_ service: AuthServiceProtocol) -> some View {
        self.environment(\.authService, service)
    }
    
    /// Inject user repository into the environment
    func userRepository(_ repository: UserRepositoryProtocol) -> some View {
        self.environment(\.userRepository, repository)
    }
    
    /// Inject health metric repository into the environment
    func healthMetricRepository(_ repository: HealthMetricRepositoryProtocol) -> some View {
        self.environment(\.healthMetricRepository, repository)
    }
    
    /// Inject API client into the environment
    func apiClient(_ client: APIClientProtocol) -> some View {
        self.environment(\.apiClient, client)
    }
    
    /// Inject persistence service into the environment
    func persistenceService(_ service: PersistenceServiceProtocol) -> some View {
        self.environment(\.persistenceService, service)
    }
    
    /// Inject model container into the environment
    func customModelContainer(_ container: ModelContainer) -> some View {
        self.environment(\.modelContainer, container)
    }
    
    /// Inject login use case into the environment
    func loginUseCase(_ useCase: LoginUseCaseProtocol) -> some View {
        self.environment(\.loginUseCase, useCase)
    }
}
