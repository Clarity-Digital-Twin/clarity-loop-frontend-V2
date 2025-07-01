//
//  EnvironmentKeys+ViewModels.swift
//  clarity-loop-frontend-v2
//
//  Environment keys for view model factories
//

import SwiftUI
import SwiftData
import ClarityCore
import ClarityDomain

// MARK: - LoginViewModelFactory

private struct LoginViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LoginViewModelFactory = DefaultLoginViewModelFactory(
        loginUseCase: FatalErrorLoginUseCase()
    )
}

public extension EnvironmentValues {
    var loginViewModelFactory: LoginViewModelFactory {
        get { self[LoginViewModelFactoryKey.self] }
        set { self[LoginViewModelFactoryKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorLoginUseCase: LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> User {
        fatalError("💥 LoginUseCaseProtocol not injected - withDependencies() failed")
    }
}

// MARK: - DashboardViewModelFactory

private struct DashboardViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: DashboardViewModelFactory = DefaultDashboardViewModelFactory(
        healthMetricRepository: FatalErrorHealthMetricRepository()
    )
}

public extension EnvironmentValues {
    var dashboardViewModelFactory: DashboardViewModelFactory {
        get { self[DashboardViewModelFactoryKey.self] }
        set { self[DashboardViewModelFactoryKey.self] = newValue }
    }
}

// Fatal error placeholder for missing dependency
private struct FatalErrorHealthMetricRepository: HealthMetricRepositoryProtocol {
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

// MARK: - View Extension for Dependencies

public extension View {
    /// Inject all dependencies from a configured Dependencies container
    func withDependencies(_ deps: Dependencies) -> some View {
        self
            // Existing keys from AppDependencies+SwiftUI
            .environment(\.dependencies, deps)
            .environment(\.authService, deps.require(AuthServiceProtocol.self))
            .environment(\.userRepository, deps.require(UserRepositoryProtocol.self))
            .environment(\.healthMetricRepository, deps.require(HealthMetricRepositoryProtocol.self))
            .environment(\.apiClient, deps.require(APIClientProtocol.self))
            .environment(\.persistenceService, deps.require(PersistenceServiceProtocol.self))
            .environment(\.modelContainer, deps.require(ModelContainer.self))
            .environment(\.loginUseCase, deps.require(LoginUseCaseProtocol.self))
            // New factory keys  
            .environment(\.loginViewModelFactory, deps.require(LoginViewModelFactory.self))
            .environment(\.dashboardViewModelFactory, deps.require(DashboardViewModelFactory.self))
    }
}