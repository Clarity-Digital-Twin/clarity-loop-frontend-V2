//
//  BaseIntegrationTestCase.swift
//  clarity-loop-frontend-v2Tests
//
//  Base class for integration tests that verify multiple components working together
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

/// Base test case for integration tests
open class BaseIntegrationTestCase: BaseUnitTestCase {
    
    // MARK: - Properties
    
    /// Test-specific DI container
    private(set) var testContainer: DIContainer!
    
    /// Test network client with mocking capabilities
    private(set) var testNetworkClient: MockNetworkClient!
    
    /// Test persistence service
    private(set) var testPersistence: MockPersistenceService!
    
    /// Test auth service
    private(set) var testAuthService: MockAuthService!
    
    // MARK: - Setup & Teardown
    
    /// Set up integration test environment
    open func setUpIntegration() {
        // Create isolated test container
        testContainer = DIContainer()
        
        // Configure test infrastructure
        configureTestInfrastructure()
        
        // Configure data layer
        configureTestDataLayer()
        
        // Configure domain layer
        configureTestDomainLayer()
    }
    
    /// Clean up integration test environment
    open func tearDownIntegration() {
        // Clean up test data
        testPersistence?.clearAll()
        
        // Reset container
        testContainer = nil
        testNetworkClient = nil
        testPersistence = nil
        testAuthService = nil
    }
    
    // MARK: - Configuration
    
    private func configureTestInfrastructure() {
        // Network client
        testNetworkClient = MockNetworkClient()
        testContainer.register(APIClientProtocol.self, scope: .singleton) { _ in
            self.testNetworkClient
        }
        
        // Persistence
        testPersistence = MockPersistenceService()
        testContainer.register(PersistenceServiceProtocol.self, scope: .singleton) { _ in
            self.testPersistence
        }
        
        // Auth service
        testAuthService = MockAuthService()
        testContainer.register(AuthServiceProtocol.self, scope: .singleton) { _ in
            self.testAuthService
        }
    }
    
    private func configureTestDataLayer() {
        // User repository
        testContainer.register(UserRepositoryProtocol.self, scope: .singleton) { container in
            UserRepositoryImplementation(
                apiClient: container.require(APIClientProtocol.self),
                persistence: container.require(PersistenceServiceProtocol.self)
            )
        }
        
        // Health metric repository
        testContainer.register(HealthMetricRepositoryProtocol.self, scope: .singleton) { container in
            HealthMetricRepositoryImplementation(
                apiClient: container.require(APIClientProtocol.self),
                persistence: container.require(PersistenceServiceProtocol.self)
            )
        }
    }
    
    private func configureTestDomainLayer() {
        // Login use case
        testContainer.register(LoginUseCaseProtocol.self, scope: .transient) { container in
            LoginUseCase(
                authService: container.require(AuthServiceProtocol.self),
                userRepository: container.require(UserRepositoryProtocol.self)
            )
        }
        
        // Record health metric use case
        testContainer.register(RecordHealthMetricUseCase.self, scope: .transient) { container in
            RecordHealthMetricUseCase(
                repository: container.require(HealthMetricRepositoryProtocol.self)
            )
        }
    }
    
    // MARK: - Test Helpers
    
    /// Create a test user with optional customization
    func createTestUser(
        id: UUID = UUID(),
        email: String = "test@example.com",
        firstName: String = "Test",
        lastName: String = "User"
    ) -> User {
        return User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }
    
    /// Create a test health metric
    func createTestHealthMetric(
        userId: UUID = UUID(),
        type: HealthMetricType = .heartRate,
        value: Double = 72
    ) -> HealthMetric {
        return HealthMetric(
            userId: userId,
            type: type,
            value: value,
            unit: type.defaultUnit,
            recordedAt: Date()
        )
    }
    
    /// Verify data flow between components
    func verifyDataFlow<T: Equatable>(
        from source: () async throws -> T,
        to destination: () async throws -> T,
        message: String = "Data should flow correctly between components"
    ) async throws {
        // Get data from source
        let sourceData = try await source()
        
        // Get data from destination
        let destinationData = try await destination()
        
        // Verify they match
        XCTAssertEqual(sourceData, destinationData, message)
    }
    
    /// Set up mock network response
    func givenNetworkResponse<T: Encodable>(
        for path: String,
        response: T,
        statusCode: Int = 200
    ) {
        testNetworkClient.setMockResponse(
            for: path,
            response: response,
            statusCode: statusCode
        )
    }
    
    /// Set up mock network error
    func givenNetworkError(
        for path: String,
        error: NetworkError
    ) {
        testNetworkClient.setMockError(
            for: path,
            error: error
        )
    }
    
    /// Verify network request was made
    func verifyNetworkRequest(
        to path: String,
        method: String? = nil,
        times: Int = 1
    ) {
        let requests = testNetworkClient.capturedRequests.filter { request in
            request.path == path && (method == nil || request.method == method)
        }
        
        XCTAssertEqual(
            requests.count,
            times,
            "Expected \(times) request(s) to \(path), but found \(requests.count)"
        )
    }
}

// MARK: - Mock Services

/// Mock network client for integration tests
final class MockNetworkClient: APIClientProtocol {
    
    struct CapturedRequest {
        let path: String
        let method: String
        let body: Any?
        let parameters: [String: String]?
    }
    
    private let mockResponses = NSMutableDictionary()
    private let mockErrors = NSMutableDictionary()
    private let capturedRequestsLock = NSLock()
    private var _capturedRequests: [CapturedRequest] = []
    
    var capturedRequests: [CapturedRequest] {
        capturedRequestsLock.lock()
        defer { capturedRequestsLock.unlock() }
        return _capturedRequests
    }
    
    func setMockResponse<T: Encodable>(for path: String, response: T, statusCode: Int = 200) {
        mockResponses[path] = response
    }
    
    func setMockError(for path: String, error: Error) {
        mockErrors[path] = error
    }
    
    func request<T: Decodable, E: Encodable>(
        _ method: String,
        path: String,
        body: E?,
        parameters: [String: String]?,
        headers: [String: String]?
    ) async throws -> T {
        // Capture request
        capturedRequestsLock.lock()
        _capturedRequests.append(CapturedRequest(
            path: path,
            method: method,
            body: body,
            parameters: parameters
        ))
        capturedRequestsLock.unlock()
        
        // Check for mock error
        if let error = mockErrors[path] {
            throw error
        }
        
        // Check for mock response
        if let response = mockResponses[path] {
            if let typedResponse = response as? T {
                return typedResponse
            }
            
            // If response doesn't match expected type, throw error
            throw NetworkError.decodingFailed("Mock response type mismatch")
        }
        
        throw NetworkError.requestFailed("No mock response configured")
    }
    
    func get<T: Decodable>(_ path: String, parameters: [String: String]?) async throws -> T {
        return try await request("GET", path: path, body: nil as String?, parameters: parameters, headers: nil)
    }
    
    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        return try await request("POST", path: path, body: body, parameters: nil, headers: nil)
    }
    
    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        return try await request("PUT", path: path, body: body, parameters: nil, headers: nil)
    }
    
    func delete<T: Decodable>(_ path: String) async throws -> T {
        return try await request("DELETE", path: path, body: nil as String?, parameters: nil, headers: nil)
    }
}

/// Mock persistence service for integration tests
final class MockPersistenceService: PersistenceServiceProtocol {
    
    private let storageLock = NSLock()
    private var storage: [String: Any] = [:]
    
    func save<T>(_ object: T) async throws where T: Identifiable {
        let key = "\(type(of: object))-\(object.id)"
        storageLock.lock()
        storage[key] = object
        storageLock.unlock()
    }
    
    func fetch<T>(_ id: T.ID) async throws -> T? where T: Identifiable {
        let key = "\(T.self)-\(id)"
        storageLock.lock()
        defer { storageLock.unlock() }
        return storage[key] as? T
    }
    
    func fetchAll<T>() async throws -> [T] where T: Identifiable {
        storageLock.lock()
        defer { storageLock.unlock() }
        return storage.values.compactMap { $0 as? T }
    }
    
    func delete<T>(type: T.Type, id: T.ID) async throws where T: Identifiable {
        let key = "\(type)-\(id)"
        storageLock.lock()
        storage.removeValue(forKey: key)
        storageLock.unlock()
    }
    
    func clearAll() {
        storageLock.lock()
        storage.removeAll()
        storageLock.unlock()
    }
}

/// Mock auth service for integration tests
final class MockAuthService: AuthServiceProtocol {
    
    private let lock = NSLock()
    private var _mockAuthToken: AuthToken?
    private var _mockUser: User?
    private var _shouldFailLogin = false
    
    var mockAuthToken: AuthToken? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mockAuthToken
        }
        set {
            lock.lock()
            _mockAuthToken = newValue
            lock.unlock()
        }
    }
    
    var mockUser: User? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mockUser
        }
        set {
            lock.lock()
            _mockUser = newValue
            lock.unlock()
        }
    }
    
    var shouldFailLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldFailLogin
        }
        set {
            lock.lock()
            _shouldFailLogin = newValue
            lock.unlock()
        }
    }
    
    func login(email: String, password: String) async throws -> AuthToken {
        if shouldFailLogin {
            throw AuthError.invalidCredentials
        }
        
        return mockAuthToken ?? AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    func logout() async throws {
        mockAuthToken = nil
        mockUser = nil
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        return mockAuthToken ?? AuthToken(
            accessToken: "mock-refreshed-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        return mockUser
    }
}