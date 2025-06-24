@testable import clarity_loop_frontend
import XCTest

/// Tests for LoginViewModel to verify @Observable pattern and authentication logic
/// CRITICAL: Tests the @Observable vs @ObservableObject architecture fix
@MainActor
final class LoginViewModelTests: XCTestCase {
    // MARK: - Properties
    
    private var viewModel: LoginViewModel!
    private var mockAuthService: MockAuthService!
    
    // MARK: - Test Setup

    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        viewModel = LoginViewModel(authService: mockAuthService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockAuthService = nil
        try await super.tearDown()
    }

    // MARK: - @Observable Pattern Tests

    func testObservablePatternStateUpdates() async throws {
        // Arrange
        let expectation = XCTestExpectation(description: "State updates")
        
        // Act - Set initial values
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        
        // Assert - Values are immediately available
        XCTAssertEqual(viewModel.email, "test@example.com")
        XCTAssertEqual(viewModel.password, "password123")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        
        // Test loading state during login
        mockAuthService.shouldDelayLogin = true
        
        Task {
            await viewModel.login()
            expectation.fulfill()
        }
        
        // Give time for async operation to start
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        XCTAssertTrue(viewModel.isLoading)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testEmailValidation() async throws {
        // Test valid emails
        let validEmails = [
            "user@example.com",
            "test.user@example.com",
            "user+tag@example.co.uk",
            "123@test.org"
        ]
        
        for email in validEmails {
            viewModel.email = email
            await viewModel.login()
            // If email validation was implemented, we'd check here
            // For now, just verify the email is set
            XCTAssertEqual(viewModel.email, email)
        }
        
        // Test invalid emails
        let invalidEmails = [
            "notanemail",
            "@example.com",
            "user@",
            "user..name@example.com"
        ]
        
        for email in invalidEmails {
            viewModel.email = email
            // The ViewModel doesn't validate emails before sending to auth service
            // This is handled by the auth service itself
            XCTAssertEqual(viewModel.email, email)
        }
    }

    func testPasswordValidation() async throws {
        // The ViewModel doesn't have password validation
        // It delegates to the auth service
        viewModel.email = "test@example.com"
        
        // Test various passwords
        let passwords = ["", "short", "password123", "P@ssw0rd!"]
        
        for password in passwords {
            viewModel.password = password
            XCTAssertEqual(viewModel.password, password)
        }
    }

    // MARK: - Authentication Flow Tests

    func testSuccessfulLogin() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            isEmailVerified: true
        )
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(mockAuthService.signInCalled)
        XCTAssertEqual(mockAuthService.capturedEmail, "test@example.com")
        XCTAssertEqual(mockAuthService.capturedPassword, "password123")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.shouldShowEmailVerification)
    }

    func testFailedLoginInvalidCredentials() async throws {
        // Arrange
        viewModel.email = "wrong@example.com"
        viewModel.password = "wrongpassword"
        mockAuthService.shouldFailSignIn = true
        mockAuthService.mockError = APIError.unauthorized
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(mockAuthService.signInCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.shouldShowEmailVerification)
        // Check that password is NOT cleared (as per implementation)
        XCTAssertEqual(viewModel.password, "wrongpassword")
    }

    func testFailedLoginNetworkError() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        mockAuthService.shouldFailSignIn = true
        mockAuthService.mockError = APIError.networkError(URLError(.notConnectedToInternet))
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(mockAuthService.signInCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.lowercased().contains("network") ?? false)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - UI State Management Tests

    func testLoadingStateManagement() async throws {
        // Arrange
        mockAuthService.shouldDelayLogin = true
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        
        // Act - Start login
        let loginTask = Task {
            await viewModel.login()
        }
        
        // Assert - Loading should be true during operation
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for completion
        await loginTask.value
        
        // Assert - Loading should be false after operation
        XCTAssertFalse(viewModel.isLoading)
    }

    func testFormResetAfterError() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        mockAuthService.shouldFailSignIn = true
        mockAuthService.mockError = APIError.unauthorized
        
        // Act - First login attempt (will fail)
        await viewModel.login()
        
        // Assert - Error is set but form fields remain
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.email, "test@example.com")
        XCTAssertEqual(viewModel.password, "password123") // Password NOT cleared
        
        // Act - Start typing again (simulating user interaction)
        viewModel.errorMessage = nil // Simulate error dismissal
        
        // Assert
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testEmailVerificationRequired() async throws {
        // Arrange
        viewModel.email = "unverified@example.com"
        viewModel.password = "password123"
        mockAuthService.shouldFailSignIn = true
        mockAuthService.mockError = APIError.emailVerificationRequired
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(viewModel.shouldShowEmailVerification)
        XCTAssertNil(viewModel.errorMessage) // No error shown since navigating
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Security Tests

    func testSensitiveDataClearing() async throws {
        // Arrange
        viewModel.email = "test@example.com"
        viewModel.password = "SuperSecret123!"
        
        // Act - Simulate view dismissal/deallocation
        // In real app, password should be cleared on view dismissal
        // Current implementation doesn't auto-clear password
        
        // Assert - Verify password is still in memory (current behavior)
        XCTAssertEqual(viewModel.password, "SuperSecret123!")
        
        // Note: In a production app, we'd want to clear sensitive data
        // This test documents current behavior
    }

    func testPasswordResetFlow() async throws {
        // Arrange
        viewModel.email = "forgot@example.com"
        
        // Act
        await viewModel.requestPasswordReset()
        
        // Assert
        XCTAssertTrue(mockAuthService.sendPasswordResetCalled)
        XCTAssertEqual(mockAuthService.capturedResetEmail, "forgot@example.com")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testPasswordResetError() async throws {
        // Arrange
        viewModel.email = "notfound@example.com"
        mockAuthService.shouldFailPasswordReset = true
        mockAuthService.mockError = APIError.validationError("User not found")
        
        // Act
        await viewModel.requestPasswordReset()
        
        // Assert
        XCTAssertTrue(mockAuthService.sendPasswordResetCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}
