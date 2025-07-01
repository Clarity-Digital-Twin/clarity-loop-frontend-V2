//
//  DefaultViewModelFactories.swift
//  ClarityUI
//
//  Default implementations of ViewModel factories
//

import Foundation
import ClarityDomain
import ClarityCore

/// Default factory for creating LoginViewModel instances
public struct DefaultLoginViewModelFactory: LoginViewModelFactory {
    private let loginUseCase: LoginUseCaseProtocol
    
    public init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }
    
    public func create() -> LoginUseCaseProtocol {
        return loginUseCase
    }
}

/// Default factory for creating DashboardViewModel instances
public struct DefaultDashboardViewModelFactory: DashboardViewModelFactory {
    private let healthMetricRepository: HealthMetricRepositoryProtocol
    
    public init(healthMetricRepository: HealthMetricRepositoryProtocol) {
        self.healthMetricRepository = healthMetricRepository
    }
    
    public func create(_ user: User) -> DashboardViewModel {
        // Capture repository before entering MainActor context
        let repository = self.healthMetricRepository
        
        // We need to use MainActor.assumeIsolated since DashboardViewModel requires MainActor
        // This is safe because create() is always called from View context which is MainActor
        return MainActor.assumeIsolated {
            DashboardViewModel(user: user, healthMetricRepository: repository)
        }
    }
}