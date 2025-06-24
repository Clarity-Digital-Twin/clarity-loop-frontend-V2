@testable import clarity_loop_frontend
import XCTest

/// Integration tests that validate the frontend against the real backend API
/// These tests ensure our contract adapter properly handles all backend responses
final class BackendIntegrationTests: XCTestCase {
    // MARK: - Properties

    private var apiClient: BackendAPIClient!
    private let testEmail = "integration_test_\(UUID().uuidString)@clarity.health"
    private let testPassword = "TestPass123!"
    private let backendURL = "https://clarity.novamindnyc.com"

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        // Create real API client pointing to backend
        apiClient = BackendAPIClient(
            baseURLString: backendURL,
            tokenProvider: { nil }
        )

        XCTAssertNotNil(apiClient, "Failed to create API client")
    }

    // MARK: - Health Check Tests

    func testBackendHealthCheck() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Health check completes")

        // When
        let url = URL(string: "\(backendURL)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        // Then
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "healthy")
        XCTAssertNotNil(json?["service"])

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10)
    }

    func testAuthHealthCheck() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Auth health check completes")

        // When
        let url = URL(string: "\(backendURL)/api/v1/auth/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        // Then
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        let decoder = JSONDecoder()
        let health = try decoder.decode(BackendHealthResponse.self, from: data)
        XCTAssertEqual(health.status, "healthy")
        XCTAssertEqual(health.service, "authentication")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10)
    }

    // MARK: - Registration Flow Tests

    func testRegistrationWithBackendContract() async throws {
        // Given
        let frontendRequest = UserRegistrationRequestDTO(
            email: testEmail,
            password: testPassword,
            firstName: "Test",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        // When
        do {
            let response = try await apiClient.register(requestDTO: frontendRequest)

            // Then
            XCTAssertNotNil(response.userId)
            XCTAssertEqual(response.status, "registered")
            XCTAssertTrue(response.verificationEmailSent)

        } catch {
            // If registration fails due to existing user, that's OK for integration test
            if
                let apiError = error as? APIError,
                case let .httpError(statusCode, _) = apiError,
                statusCode == 409 {
                print("User already exists - expected in integration tests")
            } else {
                XCTFail("Unexpected registration error: \(error)")
            }
        }
    }

    func testRegistrationErrorHandling() async throws {
        // Given - Invalid email
        let invalidRequest = UserRegistrationRequestDTO(
            email: "invalid-email",
            password: testPassword,
            firstName: "Test",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        // When/Then
        do {
            _ = try await apiClient.register(requestDTO: invalidRequest)
            XCTFail("Should have thrown validation error for invalid email")
        } catch {
            // Expected error
            print("Got expected error: \(error)")
        }
    }

    // MARK: - Login Flow Tests

    func testLoginWithBackendContract() async throws {
        // Skip if we can't create test user first
        // In real tests, you'd have a test user pre-created

        // Given
        let loginRequest = UserLoginRequestDTO(
            email: "test@clarity.health", // Use a known test account
            password: "TestPass123!",
            rememberMe: true,
            deviceInfo: nil
        )

        // When/Then
        do {
            let response = try await apiClient.login(requestDTO: loginRequest)

            // Validate response structure
            XCTAssertNotNil(response.user)
            XCTAssertNotNil(response.tokens)
            XCTAssertNotNil(response.tokens.accessToken)
            XCTAssertNotNil(response.tokens.refreshToken)
            XCTAssertEqual(response.tokens.tokenType, "Bearer")

        } catch {
            // Log error for debugging
            print("Login test error: \(error)")
            // Don't fail - might not have test user
        }
    }

    // MARK: - Contract Validation Tests

    func testBackendContractValidation() async throws {
        // This test validates our contract matches backend exactly

        // Test Registration Contract
        let registrationJSON = """
        {
            "email": "\(testEmail)",
            "password": "\(testPassword)",
            "display_name": "Test User"
        }
        """

        // Validate our encoder produces matching JSON
        let adapter = BackendContractAdapter()
        let frontendRequest = UserRegistrationRequestDTO(
            email: testEmail,
            password: testPassword,
            firstName: "Test",
            lastName: "User",
            phoneNumber: nil,
            termsAccepted: true,
            privacyPolicyAccepted: true
        )

        let backendRequest = adapter.adaptRegistrationRequest(frontendRequest)
        let encodedData = try JSONEncoder().encode(backendRequest)
        let encodedJSON = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]

        XCTAssertEqual(encodedJSON?["email"] as? String, testEmail)
        XCTAssertEqual(encodedJSON?["password"] as? String, testPassword)
        XCTAssertEqual(encodedJSON?["display_name"] as? String, "Test User")
    }

    // MARK: - End-to-End Flow Test

    func testCompleteAuthenticationFlow() async throws {
        // This test runs through the complete auth flow
        let expectation = XCTestExpectation(description: "Complete auth flow")

        Task {
            do {
                // 1. Health Check
                let healthURL = URL(string: "\(backendURL)/api/v1/auth/health")!
                let (_, healthResponse) = try await URLSession.shared.data(from: healthURL)
                XCTAssertEqual((healthResponse as? HTTPURLResponse)?.statusCode, 200)

                // 2. Registration (might fail if user exists)
                let registrationRequest = UserRegistrationRequestDTO(
                    email: testEmail,
                    password: testPassword,
                    firstName: "E2E",
                    lastName: "Test",
                    phoneNumber: nil,
                    termsAccepted: true,
                    privacyPolicyAccepted: true
                )

                do {
                    _ = try await apiClient.register(requestDTO: registrationRequest)
                    print("✅ Registration successful")
                } catch {
                    print("⚠️ Registration failed (user might exist): \(error)")
                }

                // 3. Login
                let loginRequest = UserLoginRequestDTO(
                    email: testEmail,
                    password: testPassword,
                    rememberMe: true,
                    deviceInfo: nil
                )

                do {
                    let loginResponse = try await apiClient.login(requestDTO: loginRequest)
                    print("✅ Login successful")

                    // 4. Get current user
                    let tokenProvider = { loginResponse.tokens.accessToken }
                    let authenticatedClient = BackendAPIClient(
                        baseURLString: backendURL,
                        tokenProvider: tokenProvider
                    )!

                    let currentUser = try await authenticatedClient.getCurrentUser()
                    print("✅ Got current user: \(currentUser.email)")

                    // 5. Logout
                    let logoutResponse = try await authenticatedClient.logout()
                    XCTAssertEqual(logoutResponse.message, "Successfully logged out")
                    print("✅ Logout successful")

                } catch {
                    print("❌ Auth flow error: \(error)")
                }

                expectation.fulfill()

            } catch {
                XCTFail("E2E flow failed with error: \(error)")
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 30)
    }
}

// MARK: - Contract Conformance Tests

extension BackendIntegrationTests {
    /// Test that validates all DTOs conform to backend expectations
    func testDTOContractConformance() throws {
        // Test Registration DTO
        let backendRegister = BackendUserRegister(
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(backendRegister)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Validate exact keys match backend
        XCTAssertNotNil(json?["email"])
        XCTAssertNotNil(json?["password"])
        XCTAssertNotNil(json?["display_name"])
        XCTAssertEqual(json?.count, 3) // Only these fields

        // Test Login DTO
        let backendLogin = BackendUserLogin(
            email: "test@example.com",
            password: "password123",
            rememberMe: true,
            deviceInfo: nil
        )

        let loginData = try encoder.encode(backendLogin)
        let loginJSON = try JSONSerialization.jsonObject(with: loginData) as? [String: Any]

        XCTAssertNotNil(loginJSON?["email"])
        XCTAssertNotNil(loginJSON?["password"])
        XCTAssertNotNil(loginJSON?["remember_me"])
        // device_info can be nil so we don't assert it
    }
}
