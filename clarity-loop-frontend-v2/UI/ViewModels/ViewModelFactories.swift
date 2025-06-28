//
//  ViewModelFactories.swift
//  ClarityUI
//
//  Factory protocols for creating ViewModels - pure SwiftUI approach
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
