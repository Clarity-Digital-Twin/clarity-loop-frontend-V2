@testable import clarity_loop_frontend
import XCTest

@MainActor
final class AuthServiceTests: XCTestCase {
    var authService: MockAuthService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // MockAuthService creation moved to async context in tests
    }

    override func tearDownWithError() throws {
        authService = nil
        try super.tearDownWithError()
    }

    func testSignInSuccess() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = true
        let email = "test@example.com"
        let password = "password123"

        // When
        let userSession = try await authService.signIn(withEmail: email, password: password)

        // Then
        XCTAssertEqual(userSession.email, email)
        XCTAssertEqual(userSession.displayName, "Test User")
        XCTAssertTrue(userSession.isEmailVerified)

        // Verify auth state updated
        XCTAssertNotNil(authService.currentUser)
        XCTAssertEqual(authService.currentUser?.email, email)
        XCTAssertEqual(authService.currentUser?.uid, "signed-in-uid")
    }

    func testSignInFailure() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = false
        let email = "test@example.com"
        let password = "wrongpassword"

        // When/Then
        do {
            _ = try await authService.signIn(withEmail: email, password: password)
            XCTFail("Expected sign in to fail")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testRegisterSuccess() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = true
        let email = "newuser@example.com"
        let password = "password123"
        let details = UserRegistrationRequestDTO(
            email: email,
            password: password,
            firstName: "New",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        // When
        let response = try await authService.register(withEmail: email, password: password, details: details)

        // Then
        XCTAssertEqual(response.email, email)
        XCTAssertEqual(response.status, "pending_verification")
        XCTAssertTrue(response.verificationEmailSent)
    }

    func testSignOut() async throws {
        // Given - user is signed in
        authService = MockAuthService()
        authService.mockCurrentUser = AuthUser(uid: "test-uid", email: "test@example.com")
        XCTAssertNotNil(authService.currentUser)

        // When
        try await authService.signOut()

        // Then
        XCTAssertNil(authService.currentUser)
    }

    func testGetCurrentUserToken() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = true

        // When
        let token = try await authService.getCurrentUserToken()

        // Then
        XCTAssertEqual(token, "mock-jwt-token")
    }

    func testGetCurrentUserTokenFailure() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = false

        // When/Then
        do {
            _ = try await authService.getCurrentUserToken()
            XCTFail("Expected token retrieval to fail")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testAuthStateStream() async throws {
        // Given
        authService = MockAuthService()
        let expectedUser = AuthUser(uid: "test-uid", email: "test@example.com", isEmailVerified: true)
        authService.mockCurrentUser = expectedUser

        // When
        var receivedUser: AuthUser?
        for await user in authService.authState {
            receivedUser = user
            break // Just get the first emission
        }

        // Then
        XCTAssertEqual(receivedUser, expectedUser)
    }

    // MARK: - Test Cases

    func testLogin_Success() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = true

        // When
        let userSession = try await authService.signIn(withEmail: "test@example.com", password: "password")

        // Then
        XCTAssertEqual(userSession.email, "test@example.com")
        XCTAssertNotNil(authService.currentUser)
    }

    func testLogin_Failure() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = false

        // When/Then
        do {
            _ = try await authService.signIn(withEmail: "test@example.com", password: "wrongpassword")
            XCTFail("Expected sign in to fail")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testRegistration_Success() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = true
        let details = UserRegistrationRequestDTO(
            email: "newuser@example.com",
            password: "password123",
            firstName: "New",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        // When
        let response = try await authService.register(
            withEmail: details.email,
            password: details.password,
            details: details
        )

        // Then
        XCTAssertEqual(response.email, details.email)
        XCTAssertEqual(response.status, "pending_verification")
    }

    func testRegistration_Failure() async throws {
        // Given
        authService = MockAuthService()
        authService.shouldSucceed = false
        let details = UserRegistrationRequestDTO(
            email: "newuser@example.com",
            password: "password123",
            firstName: "New",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        // When/Then
        do {
            _ = try await authService.register(withEmail: details.email, password: details.password, details: details)
            XCTFail("Expected registration to fail")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testLogout_Success() async throws {
        // Given
        authService = MockAuthService()
        authService.mockCurrentUser = AuthUser(uid: "test-uid", email: "test@example.com", isEmailVerified: true)

        // When
        try await authService.signOut()

        // Then
        XCTAssertNil(authService.currentUser)
    }

    // Note: refreshToken is not part of AuthServiceProtocol
    // Token refresh is handled by APIClient/BackendAPIClient
}
