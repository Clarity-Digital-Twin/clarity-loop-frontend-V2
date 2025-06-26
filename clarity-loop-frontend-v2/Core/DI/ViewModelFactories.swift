//
//  ViewModelFactories.swift
//  clarity-loop-frontend-v2
//
//  Factory protocols for creating ViewModels with dependency injection
//

import Foundation
import ClarityDomain

/// Factory for creating LoginViewModel instances
public protocol LoginViewModelFactory {
    func create() -> LoginUseCaseProtocol
}

/// Factory for creating DashboardViewModel instances
public protocol DashboardViewModelFactory {
    func create(_ user: User) -> DashboardViewModel
}