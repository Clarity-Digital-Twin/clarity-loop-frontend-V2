//
//  LoginViewTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for LoginView UI behavior
//

import XCTest
import SwiftUI
@testable import ClarityUI
@testable import ClarityCore
@testable import ClarityDomain

final class LoginViewTests: XCTestCase {
    
    // MARK: - Error Presentation Tests
    
    @MainActor
    func test_loginView_shouldShowErrorAlert_whenLoginFails() {
        // Given
        let mockLoginUseCase = MockLoginUseCase()
        mockLoginUseCase.mockResult = .failure(AppError.authentication(.invalidCredentials))
        let viewModel = LoginViewModel(loginUseCase: mockLoginUseCase)
        
        // Create a test container
        let container = DIContainer()
        container.register(LoginViewModelFactory.self) { _ in
            MockLoginViewModelFactory(viewModel: viewModel)
        }
        
        // When
        viewModel.email = "test@example.com"
        viewModel.password = "wrong"
        
        // Simulate login attempt
        Task {
            await viewModel.login()
        }
        
        // Then - verify error state is set
        let expectation = expectation(description: "Error state should be set")
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if case .error(let error) = viewModel.viewState {
                XCTAssertTrue(error is AppError)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor  
    func test_loginView_shouldClearPassword_afterSuccessfulLogin() {
        // Given
        let mockLoginUseCase = MockLoginUseCase()
        let testUser = User(id: UUID(), email: "test@example.com", firstName: "Test", lastName: "User")
        mockLoginUseCase.mockResult = .success(testUser)
        let viewModel = LoginViewModel(loginUseCase: mockLoginUseCase)
        
        // When
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        
        // Simulate login
        Task {
            await viewModel.login()
        }
        
        // Then
        let expectation = expectation(description: "Password should be cleared")
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            XCTAssertEqual(viewModel.password, "")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Mocks

private final class MockLoginUseCase: LoginUseCaseProtocol {
    var mockResult: Result<User, Error> = .failure(AppError.authentication(.invalidCredentials))
    
    func execute(email: String, password: String) async throws -> User {
        switch mockResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }
}

private struct MockLoginViewModelFactory: LoginViewModelFactory {
    let viewModel: LoginViewModel
    
    func create() -> LoginUseCaseProtocol {
        MockLoginUseCase()
    }
}
