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
    nonisolated(unsafe) static let defaultValue: LoginViewModelFactory? = nil
}

extension EnvironmentValues {
    var loginViewModelFactory: LoginViewModelFactory? {
        get { self[LoginViewModelFactoryKey.self] }
        set { self[LoginViewModelFactoryKey.self] = newValue }
    }
}

// MARK: - DashboardViewModelFactory

private struct DashboardViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: DashboardViewModelFactory? = nil
}

extension EnvironmentValues {
    var dashboardViewModelFactory: DashboardViewModelFactory? {
        get { self[DashboardViewModelFactoryKey.self] }
        set { self[DashboardViewModelFactoryKey.self] = newValue }
    }
}

// MARK: - View Extension for Dependencies

public extension View {
    /// Inject all dependencies from a configured Dependencies container
    func withDependencies(_ deps: Dependencies) -> some View {
        self
            // Existing keys from AppDependencies+SwiftUI
            .environment(\.dependencies, deps)
            .environment(\.authService, deps.resolve(AuthServiceProtocol.self))
            .environment(\.userRepository, deps.resolve(UserRepositoryProtocol.self))
            .environment(\.healthMetricRepository, deps.resolve(HealthMetricRepositoryProtocol.self))
            .environment(\.apiClient, deps.resolve(APIClientProtocol.self))
            .environment(\.persistenceService, deps.resolve(PersistenceServiceProtocol.self))
            .environment(\.modelContainer, deps.resolve(ModelContainer.self))
            .environment(\.loginUseCase, deps.resolve(LoginUseCaseProtocol.self))
            // New factory keys
            .environment(\.loginViewModelFactory, deps.resolve(LoginViewModelFactory.self))
            .environment(\.dashboardViewModelFactory, deps.resolve(DashboardViewModelFactory.self))
    }
}