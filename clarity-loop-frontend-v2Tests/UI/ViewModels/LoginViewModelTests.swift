//
//  LoginViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for LoginViewModel following TDD
//

import XCTest
@testable import ClarityUI
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityCore

final class LoginViewModelTests: XCTestCase {
    
    private var sut: LoginViewModel!
    private var mockLoginUseCase: MockLoginUseCase!
    
    override func setUp() {
        super.setUp()
        let mockUseCase = MockLoginUseCase()
        mockLoginUseCase = mockUseCase
        sut = MainActor.assumeIsolated {
            LoginViewModel(loginUseCase: mockUseCase)
        }
    }
    
    override func tearDown() {
        sut = nil
        mockLoginUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    @MainActor
    func test_whenInitialized_shouldHaveIdleState() {
        // Then
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertEqual(sut.email, "")
        XCTAssertEqual(sut.password, "")
        XCTAssertFalse(sut.isLoginButtonEnabled)
    }
    
    // MARK: - Validation Tests
    
    @MainActor
    func test_whenEmailAndPasswordValid_shouldEnableLoginButton() {
        // When
        sut.email = "test@example.com"
        sut.password = "password123"
        
        // Then
        XCTAssertTrue(sut.isLoginButtonEnabled)
    }
    
    @MainActor
    func test_whenEmailInvalid_shouldDisableLoginButton() {
        // When
        sut.email = "invalid-email"
        sut.password = "password123"
        
        // Then
        XCTAssertFalse(sut.isLoginButtonEnabled)
    }
    
    @MainActor
    func test_whenPasswordEmpty_shouldDisableLoginButton() {
        // When
        sut.email = "test@example.com"
        sut.password = ""
        
        // Then
        XCTAssertFalse(sut.isLoginButtonEnabled)
    }
    
    // MARK: - Login Tests
    
    @MainActor
    func test_whenLogin_withValidCredentials_shouldTransitionToSuccessState() async {
        // Given
        let expectedUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        mockLoginUseCase.mockResult = .success(expectedUser)
        
        sut.email = "test@example.com"
        sut.password = "password123"
        
        // When
        await sut.login()
        
        // Then
        XCTAssertEqual(sut.viewState, .success(expectedUser))
        XCTAssertTrue(mockLoginUseCase.executeWasCalled)
        XCTAssertEqual(mockLoginUseCase.lastEmail, "test@example.com")
        XCTAssertEqual(mockLoginUseCase.lastPassword, "password123")
    }
    
    @MainActor
    func test_whenLogin_shouldShowLoadingState() async {
        // Given
        mockLoginUseCase.shouldDelay = true
        sut.email = "test@example.com"
        sut.password = "password123"
        
        // When
        let loginTask = Task {
            await sut.login()
        }
        
        // Allow time for loading state to be set
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        XCTAssertEqual(sut.viewState, .loading)
        
        // Cleanup
        loginTask.cancel()
    }
    
    @MainActor
    func test_whenLogin_withInvalidCredentials_shouldShowError() async {
        // Given
        mockLoginUseCase.mockResult = .failure(AppError.auth(.invalidCredentials))
        sut.email = "test@example.com"
        sut.password = "wrong"
        
        // When
        await sut.login()
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertTrue(error is AppError)
            if let appError = error as? AppError,
               case .auth(.invalidCredentials) = appError {
                // Success
            } else {
                XCTFail("Expected authentication error")
            }
        } else {
            XCTFail("Expected error state")
        }
    }
    
    @MainActor
    func test_whenLogin_withNetworkError_shouldShowError() async {
        // Given
        mockLoginUseCase.mockResult = .failure(AppError.network(.noConnection))
        sut.email = "test@example.com"
        sut.password = "password123"
        
        // When
        await sut.login()
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertTrue(error is AppError)
            if let appError = error as? AppError,
               case .network(.noConnection) = appError {
                // Success
            } else {
                XCTFail("Expected network error")
            }
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Clear Error Tests
    
    @MainActor
    func test_whenClearError_shouldResetToIdle() async {
        // Given - Create an error state through failed login
        mockLoginUseCase.mockResult = .failure(AppError.auth(.invalidCredentials))
        sut.email = "test@example.com"
        sut.password = "wrong"
        await sut.login()
        if case .error = sut.viewState {
            // Success - we have an error state
        } else {
            XCTFail("Expected error state before clearing")
        }
        
        // When
        sut.clearError()
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
    }
}

// MARK: - Mock Login Use Case

@MainActor
private final class MockLoginUseCase: LoginUseCaseProtocol {
    var mockResult: Result<User, Error> = .failure(AppError.auth(.invalidCredentials))
    var executeWasCalled = false
    var lastEmail: String?
    var lastPassword: String?
    var shouldDelay = false
    
    func execute(email: String, password: String) async throws -> User {
        executeWasCalled = true
        lastEmail = email
        lastPassword = password
        
        if shouldDelay {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        switch mockResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }
}
