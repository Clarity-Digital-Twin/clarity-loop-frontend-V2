//
//  EnvironmentKeysNoOpTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests to verify that environment keys don't crash when dependencies aren't injected
//

import Testing
import SwiftUI
@testable import ClarityUI
@testable import ClarityDomain

@MainActor
struct EnvironmentKeysNoOpTests {
    
    @Test("LoginViewModelFactory default value doesn't crash")
    func loginFactoryDefaultDoesNotCrash() async throws {
        // Get the default factory from environment
        let defaultFactory = EnvironmentValues()[\.loginViewModelFactory]
        
        // Create a use case - this should not crash
        let useCase = defaultFactory.create()
        
        // Try to execute - should throw error, not crash
        await #expect(throws: Error.self) {
            try await useCase.execute(email: "test@example.com", password: "password")
        }
    }
    
    @Test("DashboardViewModelFactory default value doesn't crash")
    func dashboardFactoryDefaultDoesNotCrash() async throws {
        // Get the default factory from environment
        let defaultFactory = EnvironmentValues()[\.dashboardViewModelFactory]
        
        // Create a test user
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create a view model - this should not crash
        let viewModel = defaultFactory.create(user)
        
        // Verify it's created
        #expect(viewModel.user.email == "test@example.com")
        
        // Try to fetch metrics - should set error state, not crash
        await viewModel.fetchRecentMetrics()
        
        // Verify error state
        if case .error = viewModel.metricsState {
            // Expected - no-op repository throws errors
        } else {
            Issue.record("Expected error state but got \(viewModel.metricsState)")
        }
    }
    
    @Test("Environment keys can be overridden with real implementations")
    func environmentKeysCanBeOverridden() async throws {
        // Create a mock implementation
        struct MockLoginUseCase: LoginUseCaseProtocol {
            func execute(email: String, password: String) async throws -> User {
                return User(
                    id: UUID(),
                    email: email,
                    firstName: "Mock",
                    lastName: "User",
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        
        struct MockLoginFactory: LoginViewModelFactory {
            func create() -> LoginUseCaseProtocol {
                MockLoginUseCase()
            }
        }
        
        // Override the environment value
        var environment = EnvironmentValues()
        environment.loginViewModelFactory = MockLoginFactory()
        
        // Get the factory
        let factory = environment.loginViewModelFactory
        let useCase = factory.create()
        
        // Execute should succeed with mock
        let user = try await useCase.execute(email: "test@example.com", password: "password")
        #expect(user.firstName == "Mock")
    }
}