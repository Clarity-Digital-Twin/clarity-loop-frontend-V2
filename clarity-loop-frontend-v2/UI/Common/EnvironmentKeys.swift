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
    public static let defaultValue: AuthServiceProtocol = FatalErrorAuthService()
}

public extension EnvironmentValues {
    var authService: AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> AuthToken {
        fatalError("💥 AuthServiceProtocol not injected - withDependencies() failed")
    }

    func logout() async throws {
        fatalError("💥 AuthServiceProtocol not injected - withDependencies() failed")
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        fatalError("💥 AuthServiceProtocol not injected - withDependencies() failed")
    }

    func getCurrentUser() async throws -> User? {
        fatalError("💥 AuthServiceProtocol not injected - withDependencies() failed")
    }
}

// MARK: - User Repository Key

public struct UserRepositoryKey: EnvironmentKey {
    public static let defaultValue: UserRepositoryProtocol = FatalErrorUserRepository()
}

public extension EnvironmentValues {
    var userRepository: UserRepositoryProtocol {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorUserRepository: UserRepositoryProtocol {
    func create(_ user: User) async throws -> User {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }

    func update(_ user: User) async throws -> User {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }

    func delete(_ id: UUID) async throws {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }

    func findById(_ id: UUID) async throws -> User? {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }

    func findByEmail(_ email: String) async throws -> User? {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }

    func findAll() async throws -> [User] {
        fatalError("💥 UserRepositoryProtocol not injected - withDependencies() failed")
    }
}

// MARK: - Health Metric Repository Key

public struct HealthMetricRepositoryKey: EnvironmentKey {
    public static let defaultValue: HealthMetricRepositoryProtocol = FatalErrorHealthMetricRepository2()
}

public extension EnvironmentValues {
    var healthMetricRepository: HealthMetricRepositoryProtocol {
        get { self[HealthMetricRepositoryKey.self] }
        set { self[HealthMetricRepositoryKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorHealthMetricRepository2: HealthMetricRepositoryProtocol {
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func findById(_ id: UUID) async throws -> HealthMetric? {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func findByUserIdAndDateRange(userId: UUID, startDate: Date, endDate: Date) async throws -> [HealthMetric] {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func findByUserIdAndType(userId: UUID, type: HealthMetricType) async throws -> [HealthMetric] {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func delete(_ id: UUID) async throws {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func deleteAllForUser(_ userId: UUID) async throws {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }

    func getLatestByType(userId: UUID, type: HealthMetricType) async throws -> HealthMetric? {
        fatalError("💥 HealthMetricRepositoryProtocol not injected - withDependencies() failed")
    }
}

// MARK: - API Client Key

public struct APIClientKey: EnvironmentKey {
    public static let defaultValue: APIClientProtocol = FatalErrorAPIClient()
}

public extension EnvironmentValues {
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorAPIClient: APIClientProtocol {
    func get<T: Decodable>(_ endpoint: String, parameters: [String : String]?) async throws -> T {
        fatalError("💥 APIClientProtocol not injected - withDependencies() failed")
    }

    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        fatalError("💥 APIClientProtocol not injected - withDependencies() failed")
    }

    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        fatalError("💥 APIClientProtocol not injected - withDependencies() failed")
    }

    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        fatalError("💥 APIClientProtocol not injected - withDependencies() failed")
    }

    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        fatalError("💥 APIClientProtocol not injected - withDependencies() failed")
    }
}

// MARK: - Persistence Service Key

public struct PersistenceServiceKey: EnvironmentKey {
    public static let defaultValue: PersistenceServiceProtocol = FatalErrorPersistenceService()
}

public extension EnvironmentValues {
    var persistenceService: PersistenceServiceProtocol {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorPersistenceService: PersistenceServiceProtocol {
    func save<T: Identifiable>(_ object: T) async throws {
        fatalError("💥 PersistenceServiceProtocol not injected - withDependencies() failed")
    }

    func fetch<T: Identifiable>(_ id: T.ID) async throws -> T? {
        fatalError("💥 PersistenceServiceProtocol not injected - withDependencies() failed")
    }

    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        fatalError("💥 PersistenceServiceProtocol not injected - withDependencies() failed")
    }

    func fetchAll<T: Identifiable>() async throws -> [T] {
        fatalError("💥 PersistenceServiceProtocol not injected - withDependencies() failed")
    }
}

// MARK: - Model Container Key

public struct ModelContainerKey: EnvironmentKey {
    public static let defaultValue: ModelContainer = FatalErrorModelContainer()
}

public extension EnvironmentValues {
    var modelContainer: ModelContainer {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private func FatalErrorModelContainer() -> ModelContainer {
    fatalError("💥 ModelContainer not injected - withDependencies() failed")
}

// MARK: - Login Use Case Key

public struct LoginUseCaseKey: EnvironmentKey {
    public static let defaultValue: LoginUseCaseProtocol = FatalErrorLoginUseCase2()
}

public extension EnvironmentValues {
    var loginUseCase: LoginUseCaseProtocol {
        get { self[LoginUseCaseKey.self] }
        set { self[LoginUseCaseKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorLoginUseCase2: LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> User {
        fatalError("💥 LoginUseCaseProtocol not injected - withDependencies() failed")
    }
}

// MARK: - View Extension for Service Injection
// These methods are now DEPRECATED - use .withDependencies() instead
// All environment keys are now NON-OPTIONAL and will crash if not properly injected

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
