//
//  DIContainerTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for Dependency Injection Container following TDD
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityUI

final class DIContainerTests: XCTestCase {
    
    private var sut: DIContainer!
    
    override func setUp() {
        super.setUp()
        sut = DIContainer()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Registration Tests
    
    func test_whenRegisteringService_shouldResolveSuccessfully() {
        // Given
        let expectedService = MockService()
        
        // When
        sut.register(MockServiceProtocol.self) { _ in
            expectedService
        }
        
        // Then
        let resolved = sut.resolve(MockServiceProtocol.self)
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved === expectedService)
    }
    
    func test_whenResolvingUnregisteredService_shouldReturnNil() {
        // When
        let resolved = sut.resolve(MockServiceProtocol.self)
        
        // Then
        XCTAssertNil(resolved)
    }
    
    func test_whenRegisteringSingleton_shouldReturnSameInstance() {
        // Given
        var creationCount = 0
        
        // When
        sut.register(MockServiceProtocol.self, scope: .singleton) { _ in
            creationCount += 1
            return MockService()
        }
        
        let first = sut.resolve(MockServiceProtocol.self)
        let second = sut.resolve(MockServiceProtocol.self)
        
        // Then
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertTrue(first === second)
        XCTAssertEqual(creationCount, 1)
    }
    
    func test_whenRegisteringTransient_shouldReturnNewInstance() {
        // Given
        var creationCount = 0
        
        // When
        sut.register(MockServiceProtocol.self, scope: .transient) { _ in
            creationCount += 1
            return MockService()
        }
        
        let first = sut.resolve(MockServiceProtocol.self)
        let second = sut.resolve(MockServiceProtocol.self)
        
        // Then
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
        XCTAssertEqual(creationCount, 2)
    }
    
    // MARK: - Dependency Resolution Tests
    
    func test_whenResolvingWithDependencies_shouldInjectCorrectly() {
        // Given
        sut.register(MockServiceProtocol.self) { _ in
            MockService()
        }
        
        sut.register(MockRepositoryProtocol.self) { container in
            let service = container.resolve(MockServiceProtocol.self)!
            return MockRepository(service: service)
        }
        
        // When
        let repository = sut.resolve(MockRepositoryProtocol.self)
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertNotNil((repository as? MockRepository)?.service)
    }
    
    // MARK: - Real Layer Tests
    
    func test_whenRegisteringDomainLayer_shouldResolveCorrectly() {
        // Given
        registerDomainLayer()
        
        // When
        let loginUseCase = sut.resolve(LoginUseCaseProtocol.self)
        
        // Then
        XCTAssertNotNil(loginUseCase)
    }
    
    func test_whenRegisteringDataLayer_shouldResolveCorrectly() {
        // Given
        registerDataLayer()
        
        // When
        let userRepo = sut.resolve(UserRepositoryProtocol.self)
        let healthMetricRepo = sut.resolve(HealthMetricRepositoryProtocol.self)
        
        // Then
        XCTAssertNotNil(userRepo)
        XCTAssertNotNil(healthMetricRepo)
    }
    
    func test_whenRegisteringUILayer_shouldResolveViewModels() {
        // Given
        registerAllLayers()
        
        // When
        let loginVMFactory = sut.resolve(LoginViewModelFactoryImpl.self)
        let dashboardVMFactory = sut.resolve(DashboardViewModelFactoryImpl.self)
        
        // Then
        XCTAssertNotNil(loginVMFactory)
        XCTAssertNotNil(dashboardVMFactory)
    }
    
    // MARK: - Helper Methods
    
    private func registerDomainLayer() {
        // Mock implementations for testing
        sut.register(AuthServiceProtocol.self) { _ in
            MockAuthService()
        }
        
        sut.register(UserRepositoryProtocol.self) { _ in
            MockUserRepository()
        }
        
        sut.register(LoginUseCaseProtocol.self) { container in
            LoginUseCase(
                authService: container.resolve(AuthServiceProtocol.self)!,
                userRepository: container.resolve(UserRepositoryProtocol.self)!
            )
        }
    }
    
    private func registerDataLayer() {
        sut.register(APIClientProtocol.self) { _ in
            MockNetworkClient()
        }
        
        sut.register(PersistenceServiceProtocol.self) { _ in
            MockPersistence()
        }
        
        sut.register(UserRepositoryProtocol.self) { container in
            UserRepositoryImplementation(
                apiClient: container.resolve(APIClientProtocol.self)!,
                persistence: container.resolve(PersistenceServiceProtocol.self)!
            )
        }
        
        sut.register(HealthMetricRepositoryProtocol.self) { container in
            HealthMetricRepositoryImplementation(
                apiClient: container.resolve(APIClientProtocol.self)!,
                persistence: container.resolve(PersistenceServiceProtocol.self)!
            )
        }
    }
    
    private func registerAllLayers() {
        registerDataLayer()
        registerDomainLayer()
        
        // UI Layer factories
        sut.register(LoginViewModelFactoryImpl.self) { container in
            LoginViewModelFactoryImpl(
                loginUseCase: container.resolve(LoginUseCaseProtocol.self)!
            )
        }
        
        sut.register(DashboardViewModelFactoryImpl.self) { container in
            DashboardViewModelFactoryImpl(
                healthMetricRepository: container.resolve(HealthMetricRepositoryProtocol.self)!
            )
        }
    }
}

// MARK: - Mock Types

private protocol MockServiceProtocol: AnyObject {}
private final class MockService: MockServiceProtocol {}

private protocol MockRepositoryProtocol: AnyObject {}
private final class MockRepository: MockRepositoryProtocol {
    let service: MockServiceProtocol
    init(service: MockServiceProtocol) {
        self.service = service
    }
}

// MARK: - Mock Implementations

// MockAuthService is imported from Shared/Mocks/SharedMockAuthService.swift

private final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    func create(_ user: User) async throws -> User { user }
    func findById(_ id: UUID) async throws -> User? { nil }
    func findByEmail(_ email: String) async throws -> User? { nil }
    @MainActor
    func update(_ user: User) async throws -> User { user }
    func delete(_ id: UUID) async throws {}
    func findAll() async throws -> [User] { [] }
}

private final class MockNetworkClient: APIClientProtocol, @unchecked Sendable {
    init() {}
    
    func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T {
        throw NetworkError.offline
    }
    
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        throw NetworkError.offline
    }
    
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        throw NetworkError.offline
    }
    
    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        throw NetworkError.offline
    }
    
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        throw NetworkError.offline
    }
}

private final class MockPersistence: PersistenceServiceProtocol, @unchecked Sendable {
    func save<T: Identifiable>(_ object: T) async throws {}
    func fetch<T: Identifiable>(_ id: T.ID) async throws -> T? { nil }
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {}
    func fetchAll<T: Identifiable>() async throws -> [T] { [] }
}

// MARK: - Factory Implementations

private struct LoginViewModelFactoryImpl: LoginViewModelFactory {
    let loginUseCase: LoginUseCaseProtocol
    
    func create() -> LoginUseCaseProtocol {
        loginUseCase
    }
}

private struct DashboardViewModelFactoryImpl: @preconcurrency DashboardViewModelFactory {
    let healthMetricRepository: HealthMetricRepositoryProtocol
    
    func create(_ user: User) -> DashboardViewModel {
        // Since DashboardViewModel is @MainActor, we need to handle this properly
        // For testing purposes, we'll use a synchronous approach
        let viewModel = MainActor.assumeIsolated {
            DashboardViewModel(
                user: user,
                healthMetricRepository: healthMetricRepository
            )
        }
        return viewModel
    }
}
