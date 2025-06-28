//
//  NetworkServiceTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for NetworkService protocol
//

import XCTest
@testable import ClarityData
@testable import ClarityDomain
@testable import ClarityCore

final class NetworkServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: NetworkServiceProtocol!
    private var mockSession: MockURLSession!
    private var mockAuthService: MockNetworkAuthService!
    private var mockTokenStorage: MockTokenStorage!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockAuthService = MockNetworkAuthService()
        mockTokenStorage = MockTokenStorage()
        sut = NetworkService(
            baseURL: URL(string: "https://api.test.com")!,
            session: mockSession,
            authService: mockAuthService,
            tokenStorage: mockTokenStorage
        )
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        mockAuthService = nil
        mockTokenStorage = nil
        super.tearDown()
    }
    
    // MARK: - Basic Request Tests
    
    func test_request_withValidEndpoint_shouldReturnDecodedData() async throws {
        // Given
        struct TestResponse: Codable, Equatable {
            let id: String
            let name: String
        }
        
        let expectedResponse = TestResponse(id: "123", name: "Test")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(
            path: "/test",
            method: .get,
            requiresAuth: false
        )
        
        // When
        let result: TestResponse = try await sut.request(endpoint, type: TestResponse.self)
        
        // Then
        XCTAssertEqual(result, expectedResponse)
        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, "https://api.test.com/test")
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "GET")
    }
    
    func test_request_withAuthRequired_shouldAddBearerToken() async throws {
        // Given
        mockTokenStorage.mockAccessToken = "test-access-token"
        mockSession.mockData = Data("{}".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/secure")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(
            path: "/secure",
            method: .get,
            requiresAuth: true
        )
        
        // When
        _ = try await sut.request(endpoint)
        
        // Then
        XCTAssertEqual(
            mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-access-token"
        )
    }
    
    func test_request_withAuthRequired_whenNoToken_shouldThrowUnauthorized() async {
        // Given
        mockTokenStorage.mockAccessToken = nil // No token
        
        let endpoint = Endpoint(
            path: "/secure",
            method: .get,
            requiresAuth: true
        )
        
        // When/Then
        do {
            _ = try await sut.request(endpoint)
            XCTFail("Should throw unauthorized error when no token")
        } catch {
            XCTAssertEqual(error as? NetworkError, .unauthorized)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func test_request_with401Error_shouldThrowUnauthorized() async {
        // Given
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/test")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(path: "/test", method: .get)
        
        // When/Then
        do {
            _ = try await sut.request(endpoint)
            XCTFail("Should throw unauthorized error")
        } catch {
            XCTAssertEqual(error as? NetworkError, .unauthorized)
        }
    }
    
    func test_request_with404Error_shouldThrowNotFound() async {
        // Given
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/missing")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(path: "/missing", method: .get, requiresAuth: false)
        
        // When/Then
        do {
            _ = try await sut.request(endpoint)
            XCTFail("Should throw not found error")
        } catch {
            XCTAssertEqual(error as? NetworkError, .notFound)
        }
    }
    
    func test_request_with500Error_shouldThrowServerError() async {
        // Given
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/error")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data("{\"message\":\"Internal server error\"}".utf8)
        
        let endpoint = Endpoint(path: "/error", method: .get, requiresAuth: false)
        
        // When/Then
        do {
            _ = try await sut.request(endpoint)
            XCTFail("Should throw server error")
        } catch {
            if case let NetworkError.serverError(statusCode, message) = error {
                XCTAssertEqual(statusCode, 500)
                XCTAssertEqual(message, "Internal server error")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Request Building Tests
    
    func test_buildRequest_withQueryItems_shouldAppendToURL() async throws {
        // Given
        mockSession.mockData = Data("{}".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/search")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(
            path: "/search",
            method: .get,
            queryItems: [
                URLQueryItem(name: "q", value: "test"),
                URLQueryItem(name: "limit", value: "10")
            ],
            requiresAuth: false
        )
        
        // When
        _ = try await sut.request(endpoint)
        
        // Then
        XCTAssertEqual(
            mockSession.lastRequest?.url?.absoluteString,
            "https://api.test.com/search?q=test&limit=10"
        )
    }
    
    func test_buildRequest_withBody_shouldSetHTTPBody() async throws {
        // Given
        struct TestRequest: Codable {
            let name: String
            let value: Int
        }
        
        let requestBody = TestRequest(name: "test", value: 42)
        let bodyData = try JSONEncoder().encode(requestBody)
        
        mockSession.mockData = Data("{}".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/create")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(
            path: "/create",
            method: .post,
            body: bodyData,
            requiresAuth: false
        )
        
        // When
        _ = try await sut.request(endpoint)
        
        // Then
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.httpBody, bodyData)
        XCTAssertEqual(
            mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }
    
    // MARK: - Interceptor Tests
    
    func test_request_withInterceptor_shouldModifyRequest() async throws {
        // Given
        let interceptor = MockRequestInterceptor()
        interceptor.mockHeadersToAdd = ["X-Custom-Header": "custom-value"]
        
        sut = NetworkService(
            baseURL: URL(string: "https://api.test.com")!,
            session: mockSession,
            authService: mockAuthService,
            tokenStorage: mockTokenStorage,
            interceptors: [interceptor]
        )
        
        mockSession.mockData = Data("{}".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let endpoint = Endpoint(path: "/test", method: .get, requiresAuth: false)
        
        // When
        _ = try await sut.request(endpoint)
        
        // Then
        XCTAssertTrue(interceptor.interceptCalled)
        XCTAssertEqual(
            mockSession.lastRequest?.value(forHTTPHeaderField: "X-Custom-Header"),
            "custom-value"
        )
    }
}

// MARK: - Mock Classes

private final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? URLResponse()
        
        return (data, response)
    }
}

private final class MockNetworkAuthService: AuthServiceProtocol, @unchecked Sendable {
    var mockToken = "mock-token"
    var loginCalled = false
    var shouldThrowError = false
    
    func login(email: String, password: String) async throws -> AuthToken {
        loginCalled = true
        
        if shouldThrowError {
            throw AuthError.invalidCredentials
        }
        
        return AuthToken(
            accessToken: mockToken,
            refreshToken: "refresh-token",
            expiresIn: 3600
        )
    }
    
    func logout() async throws {
        // No-op for tests
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        return AuthToken(
            accessToken: mockToken,
            refreshToken: refreshToken,
            expiresIn: 3600
        )
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        return nil
    }
}

private final class MockRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    var interceptCalled = false
    var mockHeadersToAdd: [String: String] = [:]
    
    func intercept(_ request: inout URLRequest) async throws {
        interceptCalled = true
        
        for (key, value) in mockHeadersToAdd {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}

private final class MockTokenStorage: TokenStorageProtocol, @unchecked Sendable {
    var mockAccessToken: String?
    var mockToken: AuthToken?
    var saveTokenCalled = false
    var clearTokenCalled = false
    
    func saveToken(_ token: AuthToken) async throws {
        saveTokenCalled = true
        mockToken = token
        mockAccessToken = token.accessToken
    }
    
    func getToken() async throws -> AuthToken? {
        return mockToken
    }
    
    func getAccessToken() async throws -> String? {
        return mockAccessToken
    }
    
    func clearToken() async throws {
        clearTokenCalled = true
        mockToken = nil
        mockAccessToken = nil
    }
}
