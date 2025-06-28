//
//  LoginUseCaseTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for Login use case following TDD principles
//

import XCTest
@testable import ClarityDomain

final class LoginUseCaseTests: XCTestCase {
    
    // MARK: - Mocks
    
    private final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
        var shouldSucceed = true
        var mockUser: User?
        var loginCallCount = 0
        
        func login(email: String, password: String) async throws -> AuthToken {
            loginCallCount += 1
            
            if !shouldSucceed {
                throw NSError(domain: "MockAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
            }
            
            return AuthToken(
                accessToken: "mock-access-token",
                refreshToken: "mock-refresh-token",
                expiresIn: 3600
            )
        }
        
        func logout() async throws {
            // Mock implementation
        }
        
        func refreshToken(_ refreshToken: String) async throws -> AuthToken {
            return AuthToken(
                accessToken: "new-access-token",
                refreshToken: "new-refresh-token",
                expiresIn: 3600
            )
        }
        
        @MainActor
        func getCurrentUser() async throws -> User? {
            return mockUser
        }
    }
    
    private final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
        var users: [String: User] = [:]
        
        func create(_ user: User) async throws -> User {
            users[user.email] = user
            return user
        }
        
        func findById(_ id: UUID) async throws -> User? {
            users.values.first { $0.id == id }
        }
        
        func findByEmail(_ email: String) async throws -> User? {
            users[email]
        }
        
        @MainActor
        func update(_ user: User) async throws -> User {
            users[user.email] = user
            return user
        }
        
        func delete(_ id: UUID) async throws {
            users.removeValue(forKey: users.values.first { $0.id == id }?.email ?? "")
        }
        
        func findAll() async throws -> [User] {
            Array(users.values)
        }
    }
    
    // MARK: - Tests
    
    @MainActor
    func test_whenExecutingLogin_withValidCredentials_shouldReturnUser() async throws {
        // Given
        let authService = MockAuthService()
        let userRepository = MockUserRepository()
        let useCase = LoginUseCase(
            authService: authService,
            userRepository: userRepository
        )
        
        let email = "test@example.com"
        let password = "password123"
        let mockUser = User(
            id: UUID(),
            email: email,
            firstName: "Test",
            lastName: "User"
        )
        
        authService.mockUser = mockUser
        _ = try await userRepository.create(mockUser)
        
        // When
        let result = try await useCase.execute(email: email, password: password)
        
        // Then
        XCTAssertEqual(result.email, email)
        XCTAssertEqual(authService.loginCallCount, 1)
    }
    
    @MainActor
    func test_whenExecutingLogin_withInvalidCredentials_shouldThrowError() async {
        // Given
        let authService = MockAuthService()
        authService.shouldSucceed = false
        let userRepository = MockUserRepository()
        let useCase = LoginUseCase(
            authService: authService,
            userRepository: userRepository
        )
        
        // When & Then
        do {
            _ = try await useCase.execute(email: "wrong@example.com", password: "wrong")
            XCTFail("Should have thrown error")
        } catch {
            // Just verify an error was thrown
            XCTAssertNotNil(error)
        }
    }
    
    @MainActor
    func test_whenExecutingLogin_shouldUpdateLastLoginTime() async throws {
        // Given
        let authService = MockAuthService()
        let userRepository = MockUserRepository()
        let useCase = LoginUseCase(
            authService: authService,
            userRepository: userRepository
        )
        
        let email = "test@example.com"
        let mockUser = User(
            id: UUID(),
            email: email,
            firstName: "Test",
            lastName: "User"
        )
        
        authService.mockUser = mockUser
        _ = try await userRepository.create(mockUser)
        XCTAssertNil(mockUser.lastLoginAt)
        
        // When
        let result = try await useCase.execute(email: email, password: "password")
        
        // Then
        XCTAssertNotNil(result.lastLoginAt)
        let updatedUser = try await userRepository.findByEmail(email)
        XCTAssertNotNil(updatedUser?.lastLoginAt)
    }
    
    func test_whenValidatingLoginInput_withEmptyEmail_shouldReturnFalse() {
        // Given
        let useCase = LoginUseCase(
            authService: MockAuthService(),
            userRepository: MockUserRepository()
        )
        
        // When
        let isValid = useCase.validateInput(email: "", password: "password")
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func test_whenValidatingLoginInput_withEmptyPassword_shouldReturnFalse() {
        // Given
        let useCase = LoginUseCase(
            authService: MockAuthService(),
            userRepository: MockUserRepository()
        )
        
        // When
        let isValid = useCase.validateInput(email: "test@example.com", password: "")
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func test_whenValidatingLoginInput_withValidData_shouldReturnTrue() {
        // Given
        let useCase = LoginUseCase(
            authService: MockAuthService(),
            userRepository: MockUserRepository()
        )
        
        // When
        let isValid = useCase.validateInput(
            email: "test@example.com",
            password: "password123"
        )
        
        // Then
        XCTAssertTrue(isValid)
    }
}