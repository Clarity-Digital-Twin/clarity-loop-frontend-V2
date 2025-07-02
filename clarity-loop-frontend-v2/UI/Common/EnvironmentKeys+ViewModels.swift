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
import ClarityData

// MARK: - LoginViewModelFactory

private struct LoginViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LoginViewModelFactory = NoOpLoginViewModelFactory()
}

public extension EnvironmentValues {
    var loginViewModelFactory: LoginViewModelFactory {
        get { self[LoginViewModelFactoryKey.self] }
        set { self[LoginViewModelFactoryKey.self] = newValue }
    }
}

// No-op factory that returns a safe default implementation
private struct NoOpLoginViewModelFactory: LoginViewModelFactory {
    func create() -> LoginUseCaseProtocol {
        NoOpLoginUseCase()
    }
}

// Safe no-op implementation that throws an error instead of crashing
private struct NoOpLoginUseCase: LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> User {
        throw AppError.unknown
    }
}

// MARK: - DashboardViewModelFactory

private struct DashboardViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: DashboardViewModelFactory = NoOpDashboardViewModelFactory()
}

public extension EnvironmentValues {
    var dashboardViewModelFactory: DashboardViewModelFactory {
        get { self[DashboardViewModelFactoryKey.self] }
        set { self[DashboardViewModelFactoryKey.self] = newValue }
    }
}

// No-op factory that returns a safe default implementation
private struct NoOpDashboardViewModelFactory: DashboardViewModelFactory {
    func create(_ user: User) -> DashboardViewModel {
        // Capture repository before entering MainActor context
        let repository = NoOpHealthMetricRepository()
        
        // We need to use MainActor.assumeIsolated since DashboardViewModel requires MainActor
        // This is safe because create() is always called from View context which is MainActor
        return MainActor.assumeIsolated {
            DashboardViewModel(user: user, healthMetricRepository: repository)
        }
    }
}

// Safe no-op implementation that throws errors instead of crashing
private struct NoOpHealthMetricRepository: HealthMetricRepositoryProtocol {
    private let error = AppError.unknown
    
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        throw error
    }

    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        throw error
    }

    func findById(_ id: UUID) async throws -> HealthMetric? {
        throw error
    }

    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        throw error
    }

    func findByUserIdAndDateRange(userId: UUID, startDate: Date, endDate: Date) async throws -> [HealthMetric] {
        throw error
    }

    func findByUserIdAndType(userId: UUID, type: HealthMetricType) async throws -> [HealthMetric] {
        throw error
    }

    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        throw error
    }

    func delete(_ id: UUID) async throws {
        throw error
    }

    func deleteAllForUser(_ userId: UUID) async throws {
        throw error
    }

    func getLatestByType(userId: UUID, type: HealthMetricType) async throws -> HealthMetric? {
        throw error
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
