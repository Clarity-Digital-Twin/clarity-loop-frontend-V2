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
    open func tearDownIntegration() async {
        // Clean up test data
        if let persistence = testPersistence {
            await persistence.clearAll()
        }
        
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
    func givenNetworkResponse<T: Encodable & Sendable>(
        for path: String,
        response: T,
        statusCode: Int = 200
    ) async {
        await testNetworkClient.setMockResponse(
            for: path,
            response: response,
            statusCode: statusCode
        )
    }
    
    /// Set up mock network error
    func givenNetworkError(
        for path: String,
        error: NetworkError
    ) async {
        await testNetworkClient.setMockError(
            for: path,
            error: error
        )
    }
    
    /// Verify network request was made
    func verifyNetworkRequest(
        to path: String,
        method: String? = nil,
        times: Int = 1
    ) async {
        let requests = await testNetworkClient.capturedRequests.filter { request in
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

/// Wrapper to make Any sendable for test purposes
struct SendableValue: @unchecked Sendable {
    let value: Any?
}

/// Mock network client for integration tests
final class MockNetworkClient: APIClientProtocol, @unchecked Sendable {
    
    struct CapturedRequest: @unchecked Sendable {
        let path: String
        let method: String
        let body: Any?
        let parameters: [String: String]?
    }
    
    struct EmptyResponse: Codable {}
    
    private actor Storage {
        private var mockResponses: [String: SendableValue] = [:]
        private var mockErrors: [String: any Error] = [:]
        private var capturedRequests: [CapturedRequest] = []
        
        func setMockResponse(for path: String, response: Any) {
            mockResponses[path] = SendableValue(value: response)
        }
        
        func setMockError(for path: String, error: any Error) {
            mockErrors[path] = error
        }
        
        func captureRequest(_ request: CapturedRequest) {
            capturedRequests.append(request)
        }
        
        func getCapturedRequests() -> [CapturedRequest] {
            return capturedRequests
        }
        
        func getMockError(for path: String) -> (any Error)? {
            return mockErrors[path]
        }
        
        func getMockResponse(for path: String) -> SendableValue? {
            return mockResponses[path]
        }
    }
    
    private let storage = Storage()
    
    var capturedRequests: [CapturedRequest] {
        get async {
            await storage.getCapturedRequests()
        }
    }
    
    func setMockResponse<T: Encodable & Sendable>(for path: String, response: T, statusCode: Int = 200) async {
        await storage.setMockResponse(for: path, response: response)
    }
    
    func setMockError(for path: String, error: any Error) async {
        await storage.setMockError(for: path, error: error)
    }
    
    func request<T: Decodable, E: Encodable>(
        _ method: String,
        path: String,
        body: E?,
        parameters: [String: String]?,
        headers: [String: String]?
    ) async throws -> T {
        // Capture request
        await storage.captureRequest(CapturedRequest(
            path: path,
            method: method,
            body: body,
            parameters: parameters
        ))
        
        // Check for mock error
        if let error = await storage.getMockError(for: path) {
            throw error
        }
        
        // Check for mock response
        if let wrappedResponse = await storage.getMockResponse(for: path),
           let response = wrappedResponse.value {
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let typedResponse = try? JSONDecoder().decode(T.self, from: data) {
                return typedResponse
            }
            
            if let typedResponse = response as? T {
                return typedResponse
            }
            
            // If response doesn't match expected type, throw error
            throw NetworkError.decodingFailed("Mock response type mismatch")
        }
        
        throw NetworkError.offline
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
    
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        let _: EmptyResponse = try await delete("/api/v1/\(String(describing: type).lowercased())s/\(id)")
    }
}

/// Mock persistence service for integration tests
final class MockPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    
    private actor Storage {
        private var storage: [String: SendableValue] = [:]
        
        func save(key: String, value: Any) {
            storage[key] = SendableValue(value: value)
        }
        
        func fetch(key: String) -> SendableValue? {
            return storage[key]
        }
        
        func fetchAll<T>() -> [T] {
            return storage.values.compactMap { $0.value as? T }
        }
        
        func delete(key: String) {
            storage.removeValue(forKey: key)
        }
        
        func clear() {
            storage.removeAll()
        }
    }
    
    private let storage = Storage()
    
    func save<T>(_ object: T) async throws where T: Identifiable & Sendable {
        let key = "\(type(of: object))-\(object.id)"
        await storage.save(key: key, value: object)
    }
    
    func fetch<T>(_ id: T.ID) async throws -> T? where T: Identifiable {
        let key = "\(T.self)-\(id)"
        let wrapped = await storage.fetch(key: key)
        return wrapped?.value as? T
    }
    
    func fetchAll<T>() async throws -> [T] where T: Identifiable & Sendable {
        return await storage.fetchAll()
    }
    
    func delete<T>(type: T.Type, id: T.ID) async throws where T: Identifiable {
        let key = "\(type)-\(id)"
        await storage.delete(key: key)
    }
    
    func clearAll() async {
        await storage.clear()
    }
}

/// Mock auth service for integration tests
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    
    private actor Storage {
        private var mockAuthToken: AuthToken?
        private var mockUser: User?
        private var shouldFailLogin = false
        
        func setMockAuthToken(_ token: AuthToken?) {
            mockAuthToken = token
        }
        
        func getMockAuthToken() -> AuthToken? {
            return mockAuthToken
        }
        
        func setMockUser(_ user: User?) {
            mockUser = user
        }
        
        func getMockUser() -> User? {
            return mockUser
        }
        
        func setShouldFailLogin(_ value: Bool) {
            shouldFailLogin = value
        }
        
        func getShouldFailLogin() -> Bool {
            return shouldFailLogin
        }
    }
    
    private let storage = Storage()
    
    var mockAuthToken: AuthToken? {
        get async {
            await storage.getMockAuthToken()
        }
    }
    
    func setMockAuthToken(_ token: AuthToken?) async {
        await storage.setMockAuthToken(token)
    }
    
    var mockUser: User? {
        get async {
            await storage.getMockUser()
        }
    }
    
    func setMockUser(_ user: User?) async {
        await storage.setMockUser(user)
    }
    
    var shouldFailLogin: Bool {
        get async {
            await storage.getShouldFailLogin()
        }
    }
    
    func setShouldFailLogin(_ value: Bool) async {
        await storage.setShouldFailLogin(value)
    }
    
    func login(email: String, password: String) async throws -> AuthToken {
        if await storage.getShouldFailLogin() {
            throw AuthError.invalidCredentials
        }
        
        return await storage.getMockAuthToken() ?? AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    func logout() async throws {
        await storage.setMockAuthToken(nil)
        await storage.setMockUser(nil)
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        return await storage.getMockAuthToken() ?? AuthToken(
            accessToken: "mock-refreshed-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600
        )
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        return await storage.getMockUser()
    }
}
