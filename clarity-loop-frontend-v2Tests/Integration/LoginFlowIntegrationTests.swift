//
//  LoginFlowIntegrationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Integration tests for the complete login flow
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityInfrastructure

final class LoginFlowIntegrationTests: BaseIntegrationTestCase {
    
    override func setUp() {
        super.setUp()
        setUpIntegration()
    }
    
    override func tearDown() {
        // Clean up happens in setUpIntegration for next test
        // This avoids concurrency issues with tearDown
        super.tearDown()
    }
    
    // MARK: - Login Flow Integration Tests
    
    func test_loginFlow_withValidCredentials_completesSuccessfully() async throws {
        // Given - set up mock responses
        let expectedToken = AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresIn: 3600
        )
        
        let expectedUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        await testAuthService.setMockAuthToken(expectedToken)
        await testAuthService.setMockUser(expectedUser)
        
        await givenNetworkResponse(
            for: "/api/v1/users/me",
            response: UserDTO(
                id: expectedUser.id.uuidString,
                email: expectedUser.email,
                firstName: expectedUser.firstName,
                lastName: expectedUser.lastName,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                lastLoginAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        
        // When - execute login flow
        let loginUseCase = testContainer.require(LoginUseCaseProtocol.self)
        let result = try await loginUseCase.execute(
            email: "test@example.com",
            password: "password123"
        )
        
        // Then - verify complete flow
        XCTAssertEqual(result.email, expectedUser.email)
        
        // Verify network request was made
        await verifyNetworkRequest(to: "/api/v1/users/me", method: "GET")
        
        // Verify user was persisted
        let persistedUsers = try await testPersistence.fetchAll() as [User]
        XCTAssertEqual(persistedUsers.count, 1)
        XCTAssertEqual(persistedUsers.first?.email, expectedUser.email)
    }
    
    func test_loginFlow_withInvalidCredentials_throwsError() async throws {
        // Given
        await testAuthService.setShouldFailLogin(true)
        
        // When/Then
        let loginUseCase = testContainer.require(LoginUseCaseProtocol.self)
        
        do {
            _ = try await loginUseCase.execute(
                email: "invalid@example.com",
                password: "wrong"
            )
            XCTFail("Should throw error for invalid credentials")
        } catch {
            // Just verify an error was thrown
            XCTAssertNotNil(error)
        }
        
        // Verify no network requests were made
        let capturedRequests = await testNetworkClient.capturedRequests
        XCTAssertTrue(capturedRequests.isEmpty)
    }
    
    func test_loginFlow_withNetworkError_throwsAppropriateError() async throws {
        // Given - auth succeeds but user fetch fails
        await testAuthService.setMockAuthToken(AuthToken(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresIn: 3600
        ))
        
        await givenNetworkError(
            for: "/api/v1/users/me",
            error: NSError(domain: "NetworkError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"])
        )
        
        // When/Then
        let loginUseCase = testContainer.require(LoginUseCaseProtocol.self)
        
        do {
            _ = try await loginUseCase.execute(
                email: "test@example.com",
                password: "password123"
            )
            XCTFail("Should throw error for network failure")
        } catch {
            // Verify an error was thrown
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Data Flow Verification
    
    func test_loginFlow_dataFlowsBetweenLayers() async throws {
        // Given - set up complete mock data
        let userId = UUID()
        let userDTO = UserDTO(
            id: userId.uuidString,
            email: "flow@test.com",
            firstName: "Flow",
            lastName: "Test",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            lastLoginAt: ISO8601DateFormatter().string(from: Date())
        )
        
        await testAuthService.setMockAuthToken(AuthToken(
            accessToken: "flow-token",
            refreshToken: "flow-refresh",
            expiresIn: 3600
        ))
        
        await givenNetworkResponse(for: "/api/v1/users/me", response: userDTO)
        
        // When - execute through all layers
        let loginUseCase = testContainer.require(LoginUseCaseProtocol.self)
        let loginResult = try await loginUseCase.execute(
            email: "flow@test.com",
            password: "password"
        )
        
        // Then - verify data flows correctly through layers
        
        // 1. Use case returns correct data
        XCTAssertEqual(loginResult.email, "flow@test.com")
        
        // 2. Repository received and processed the data
        let userRepository = testContainer.require(UserRepositoryProtocol.self)
        let fetchedUser = try await userRepository.findById(userId)
        XCTAssertEqual(fetchedUser?.email, "flow@test.com")
        
        // 3. Data was persisted
        let persistedUser: User? = try await testPersistence.fetch(userId)
        XCTAssertEqual(persistedUser?.email, "flow@test.com")
        
        // 4. Verify data consistency across layers
        try await verifyDataFlow(
            from: { loginResult },
            to: { fetchedUser! }
        )
    }
}