//
//  ViewModelFactoryImplementations.swift
//  clarity-loop-frontend-v2
//
//  Concrete implementations of ViewModelFactory protocols
//

import Foundation
import ClarityDomain

/// Concrete implementation of LoginViewModelFactory
public final class LoginViewModelFactoryImpl: LoginViewModelFactory {
    private let authService: AuthServiceProtocol
    private let userRepository: UserRepositoryProtocol
    
    public init(
        authService: AuthServiceProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    public func create() -> LoginUseCaseProtocol {
        return LoginUseCase(
            authService: authService,
            userRepository: userRepository
        )
    }
}

/// Concrete implementation of DashboardViewModelFactory
public final class DashboardViewModelFactoryImpl: DashboardViewModelFactory {
    private let healthMetricRepository: HealthMetricRepositoryProtocol
    
    public init(healthMetricRepository: HealthMetricRepositoryProtocol) {
        self.healthMetricRepository = healthMetricRepository
    }
    
    public func create(_ user: User) -> DashboardViewModel {
        return DashboardViewModel(
            user: user,
            healthMetricRepository: healthMetricRepository
        )
    }
}