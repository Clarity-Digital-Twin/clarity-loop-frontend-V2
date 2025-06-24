@testable import clarity_loop_frontend
import XCTest

/// Tests for RegistrationViewModel to verify @Observable pattern and registration logic
/// CRITICAL: Tests password confirmation logic and form validation
final class RegistrationViewModelTests: XCTestCase {
    // MARK: - Test Setup

    var mockAuthService: MockAuthService!
    var viewModel: RegistrationViewModel!

    @MainActor override func setUpWithError() throws {
        mockAuthService = MockAuthService()
        viewModel = RegistrationViewModel(authService: mockAuthService)
    }

    override func tearDownWithError() throws {
        mockAuthService = nil
        viewModel = nil
    }

    // MARK: - @Observable Pattern Tests

    @MainActor func testObservablePatternBindings() throws {
        // Test @Observable bindings work correctly

        // Test email field binding
        viewModel.email = "test@example.com"
        XCTAssertEqual(viewModel.email, "test@example.com")

        // Test password field binding
        viewModel.password = "testPassword123"
        XCTAssertEqual(viewModel.password, "testPassword123")

        // Test confirm password field binding
        viewModel.confirmPassword = "testPassword123"
        XCTAssertEqual(viewModel.confirmPassword, "testPassword123")

        // Test real-time validation updates
        XCTAssertTrue(viewModel.isPasswordMatching, "Passwords should match")

        // Change confirm password
        viewModel.confirmPassword = "differentPassword"
        XCTAssertFalse(viewModel.isPasswordMatching, "Passwords should not match")
    }

    // MARK: - Password Validation Tests

    @MainActor func testPasswordConfirmationMatching() throws {
        // Test password confirmation validation

        // Test case: Passwords match - should pass
        viewModel.password = "validPassword123"
        viewModel.confirmPassword = "validPassword123"
        XCTAssertTrue(viewModel.isPasswordMatching, "Matching passwords should be valid")
        XCTAssertNil(viewModel.passwordMismatchError, "No error should be present when passwords match")

        // Test case: Passwords don't match - should fail
        viewModel.password = "validPassword123"
        viewModel.confirmPassword = "differentPassword456"
        XCTAssertFalse(viewModel.isPasswordMatching, "Different passwords should not match")
        XCTAssertEqual(
            viewModel.passwordMismatchError,
            "Passwords do not match",
            "Error message should indicate mismatch"
        )

        // Test case: Real-time feedback as user types
        viewModel.password = "newPassword"
        viewModel.confirmPassword = "newP" // Partial match
        XCTAssertFalse(viewModel.isPasswordMatching, "Partial passwords should not match")

        // Complete the confirm password
        viewModel.confirmPassword = "newPassword"
        XCTAssertTrue(viewModel.isPasswordMatching, "Completed passwords should match")
    }

    @MainActor func testPasswordStrengthValidation() throws {
        // Test password strength requirements

        // Test minimum length (8 characters)
        viewModel.password = "short"
        XCTAssertFalse(viewModel.isPasswordValid, "Short password should be invalid")
        XCTAssertTrue(
            viewModel.passwordErrors.contains("Password must be at least 8 characters long"),
            "Should show length error"
        )

        viewModel.password = "validPassword123"
        XCTAssertTrue(viewModel.isPasswordValid, "Valid password should pass")

        // Test with various password combinations
        let testCases = [
            ("password", false, "No uppercase, numbers, or special chars"),
            ("PASSWORD", false, "No lowercase, numbers, or special chars"),
            ("Password", false, "No numbers or special chars"),
            ("Password123", true, "Valid with uppercase, lowercase, and numbers"),
            ("Pass123!", true, "Valid with all requirements"),
            ("12345678", false, "Only numbers"),
            ("ABCDEFGH", false, "Only uppercase letters"),
        ]

        for (password, shouldBeValid, description) in testCases {
            viewModel.password = password
            XCTAssertEqual(
                viewModel.isPasswordValid,
                shouldBeValid,
                "Password '\(password)' validation failed: \(description)"
            )
        }
    }

    @MainActor func testEmptyPasswordConfirmationError() throws {
        // Test empty confirm password field

        // Set password but leave confirm password empty
        viewModel.password = "validPassword123"
        viewModel.confirmPassword = ""

        XCTAssertFalse(viewModel.isPasswordMatching, "Empty confirm password should not match")
        XCTAssertNil(viewModel.passwordMismatchError, "Should be nil for empty confirm password per UX design")

        // Test error clears when confirm password is entered
        viewModel.confirmPassword = "validPassword123"
        XCTAssertTrue(viewModel.isPasswordMatching, "Passwords should match after entering confirm password")
        XCTAssertNil(viewModel.passwordMismatchError, "Error should clear when passwords match")

        // Test real-time validation feedback
        viewModel.confirmPassword = "partial"
        XCTAssertFalse(viewModel.isPasswordMatching, "Partial confirm password should not match")
        XCTAssertNotNil(viewModel.passwordMismatchError, "Error should appear immediately")
    }

    // MARK: - Form Validation Tests

    @MainActor func testCompleteFormValidation() throws {
        // Test complete form validation logic

        // Test invalid form state
        XCTAssertFalse(viewModel.isFormValid, "Empty form should be invalid")

        // Fill out form with valid data
        viewModel.firstName = "John"
        viewModel.lastName = "Doe"
        viewModel.email = "john.doe@example.com"
        viewModel.password = "ValidPassword123"
        viewModel.confirmPassword = "ValidPassword123"
        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = true

        XCTAssertTrue(viewModel.isFormValid, "Complete valid form should be valid")

        // Test various invalid states
        viewModel.hasAcceptedTerms = false
        XCTAssertFalse(viewModel.isFormValid, "Form without terms acceptance should be invalid")

        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = false
        XCTAssertFalse(viewModel.isFormValid, "Form without privacy acceptance should be invalid")

        viewModel.hasAcceptedPrivacy = true
        viewModel.email = "invalid-email"
        XCTAssertFalse(viewModel.isFormValid, "Form with invalid email should be invalid")

        viewModel.email = "valid@example.com"
        viewModel.password = "weak"
        XCTAssertFalse(viewModel.isFormValid, "Form with weak password should be invalid")
    }

    @MainActor func testEmailValidation() throws {
        // Test email validation logic

        let validEmails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "first.last+tag@example.org",
            "user123@test-domain.com",
        ]

        let invalidEmails = [
            "invalid-email",
            "@example.com",
            "test@",
            "test.example.com",
            "test@@example.com",
            "",
        ]

        for email in validEmails {
            viewModel.email = email
            XCTAssertTrue(viewModel.isEmailValid, "Email '\(email)' should be valid")
        }

        for email in invalidEmails {
            viewModel.email = email
            XCTAssertFalse(viewModel.isEmailValid, "Email '\(email)' should be invalid")
        }
    }

    // MARK: - Registration Flow Tests

    @MainActor func testSuccessfulRegistration() async throws {
        // Test successful registration flow
        
        // Setup valid form data
        viewModel.firstName = "John"
        viewModel.lastName = "Doe"
        viewModel.email = "john.doe@example.com"
        viewModel.password = "ValidPassword123"
        viewModel.confirmPassword = "ValidPassword123"
        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = true
        
        // Mock successful response
        mockAuthService.shouldSucceed = true
        
        // Attempt registration
        await viewModel.register()
        
        // Verify success state
        XCTAssertTrue(viewModel.isRegistrationSuccessful, "Registration should be successful")
        XCTAssertFalse(viewModel.needsEmailVerification, "Should not need email verification for 200 response")
        XCTAssertNil(viewModel.errorMessage, "No error message should be present")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after completion")
    }

    @MainActor func testRegistrationWithPasswordMismatch() async throws {
        // Test registration fails when passwords don't match

        // Setup form with mismatched passwords
        viewModel.firstName = "John"
        viewModel.lastName = "Doe"
        viewModel.email = "john.doe@example.com"
        viewModel.password = "ValidPassword123"
        viewModel.confirmPassword = "DifferentPassword456"
        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = true

        // Attempt registration
        await viewModel.register()

        // Verify failure state
        XCTAssertFalse(viewModel.isRegistrationSuccessful, "Registration should fail with mismatched passwords")
        XCTAssertNotNil(viewModel.errorMessage, "Error message should be present")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after failure")
        XCTAssertEqual(viewModel.errorMessage, "Passwords do not match.", "Should show password mismatch error")
    }

    @MainActor func testRegistrationNetworkError() async throws {
        // Test registration handles network errors properly

        // Setup valid form
        viewModel.firstName = "John"
        viewModel.lastName = "Doe"
        viewModel.email = "john.doe@example.com"
        viewModel.password = "ValidPassword123"
        viewModel.confirmPassword = "ValidPassword123"
        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = true

        // Mock network failure
        mockAuthService.shouldSucceed = false

        // Attempt registration
        await viewModel.register()

        // Verify error handling
        XCTAssertFalse(viewModel.isRegistrationSuccessful, "Registration should fail with network error")
        XCTAssertNotNil(viewModel.errorMessage, "Error message should be present")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after failure")
    }

    @MainActor func testFormValidationPreventesRegistration() async throws {
        // Test that invalid form prevents registration attempt

        // Setup invalid form (missing required fields)
        viewModel.firstName = ""
        viewModel.lastName = ""
        viewModel.email = "invalid-email"
        viewModel.password = "weak"
        viewModel.confirmPassword = "different"
        viewModel.hasAcceptedTerms = false
        viewModel.hasAcceptedPrivacy = false

        // Attempt registration
        await viewModel.register()

        // Verify registration was prevented
        XCTAssertFalse(viewModel.isRegistrationSuccessful, "Registration should be prevented with invalid form")
        XCTAssertFalse(viewModel.isLoading, "Loading should remain false")

        // Should show form validation errors
        XCTAssertFalse(viewModel.isFormValid, "Form should be invalid")
    }
    
    @MainActor func testRegistrationRequiringEmailVerification() async throws {
        // Test registration that returns 202 (email verification required)
        
        // Setup valid form data
        viewModel.firstName = "Jane"
        viewModel.lastName = "Smith"
        viewModel.email = "jane.smith@example.com"
        viewModel.password = "ValidPassword123"
        viewModel.confirmPassword = "ValidPassword123"
        viewModel.hasAcceptedTerms = true
        viewModel.hasAcceptedPrivacy = true
        
        // Mock email verification required response
        mockAuthService.shouldSucceed = false
        mockAuthService.mockError = APIError.emailVerificationRequired
        
        // Attempt registration
        await viewModel.register()
        
        // Verify email verification required state
        XCTAssertTrue(viewModel.isRegistrationSuccessful, "Registration should be successful even with email verification required")
        XCTAssertTrue(viewModel.needsEmailVerification, "Should need email verification for 202 response")
        XCTAssertNil(viewModel.errorMessage, "No error message should be present for 202 response")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after completion")
    }
}
