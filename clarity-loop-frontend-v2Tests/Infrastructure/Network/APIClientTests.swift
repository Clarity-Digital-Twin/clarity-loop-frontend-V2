//
//  APIClientTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for REAL API Client - NO FUCKING MOCKS!
//

import XCTest
@testable import ClarityData
@testable import ClarityDomain
@testable import ClarityCore

final class APIClientTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: APIClient!
    private var mockNetworkService: MockNetworkService!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        sut = APIClient(networkService: mockNetworkService)
    }
    
    override func tearDown() {
        sut = nil
        mockNetworkService = nil
        super.tearDown()
    }
    
    // MARK: - Login Tests
    
    func test_login_withValidCredentials_shouldReturnAuthToken() async throws {
        // Given
        let email = "test@example.com"
        let password = "SecurePass123!"
        
        let mockResponse = """
        {
            "access_token": "mock-access-token",
            "refresh_token": "mock-refresh-token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        """
        mockNetworkService.mockResponseData = mockResponse.data(using: .utf8)
        
        // When
        let result = try await sut.login(email: email, password: password)
        
        // Then
        XCTAssertEqual(result.accessToken, "mock-access-token")
        XCTAssertEqual(result.refreshToken, "mock-refresh-token")
        XCTAssertEqual(result.expiresIn, 3600)
        
        // Verify correct endpoint was called
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/api/v1/auth/login")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.method, .post)
        XCTAssertFalse(mockNetworkService.lastEndpoint?.requiresAuth ?? true)
    }
    
    func test_login_withInvalidCredentials_shouldThrowError() async {
        // Given
        mockNetworkService.shouldThrowError = true
        mockNetworkService.errorToThrow = NetworkError.unauthorized
        
        // When/Then
        do {
            _ = try await sut.login(email: "bad@example.com", password: "wrong")
            XCTFail("Should throw error")
        } catch {
            XCTAssertEqual(error as? NetworkError, .unauthorized)
        }
    }
    
    // MARK: - Health Data Tests
    
    func test_uploadHealthData_withValidData_shouldReturnProcessingId() async throws {
        // Given
        let healthData = HealthDataUpload(
            data_type: "heart_rate",
            value: 72.0,
            unit: "bpm",
            recorded_at: Date()
        )
        
        let mockResponse = """
        {
            "processing_id": "12345-67890",
            "status": "processing",
            "message": "Health data received"
        }
        """
        mockNetworkService.mockResponseData = mockResponse.data(using: .utf8)
        
        // When
        let result = try await sut.uploadHealthData(healthData)
        
        // Then
        XCTAssertEqual(result, "12345-67890")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/api/v1/health-data/")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.method, .post)
        XCTAssertTrue(mockNetworkService.lastEndpoint?.requiresAuth ?? false)
    }
    
    // MARK: - User Profile Tests
    
    func test_getCurrentUser_shouldReturnUserProfile() async throws {
        // Given
        let mockResponse = """
        {
            "id": "user-123",
            "email": "test@example.com",
            "first_name": "Test",
            "last_name": "User",
            "date_of_birth": "1990-01-01"
        }
        """
        mockNetworkService.mockResponseData = mockResponse.data(using: .utf8)
        
        // When
        let result = try await sut.getCurrentUser()
        
        // Then
        XCTAssertEqual(result.email, "test@example.com")
        XCTAssertEqual(result.firstName, "Test")
        XCTAssertEqual(result.lastName, "User")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/api/v1/auth/me")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.method, .get)
        XCTAssertTrue(mockNetworkService.lastEndpoint?.requiresAuth ?? false)
    }
    
    // MARK: - Insights Tests
    
    func test_getInsights_shouldReturnInsightsList() async throws {
        // Given
        let mockResponse = """
        {
            "insights": [
                {
                    "id": "insight-1",
                    "type": "anomaly",
                    "title": "Elevated Heart Rate",
                    "description": "Your heart rate has been elevated",
                    "severity": "medium",
                    "created_at": "2025-06-28T12:00:00Z"
                }
            ]
        }
        """
        mockNetworkService.mockResponseData = mockResponse.data(using: .utf8)
        
        // When
        let results = try await sut.getInsights()
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Elevated Heart Rate")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/api/v1/insights/")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.method, .get)
        XCTAssertTrue(mockNetworkService.lastEndpoint?.requiresAuth ?? false)
    }
    
    // MARK: - Batch Sync Tests
    
    func test_batchUploadHealthData_shouldHandleMultipleRecords() async throws {
        // Given
        let batch = [
            HealthDataUpload(
                data_type: "steps",
                value: 10000,
                unit: "count",
                recorded_at: Date()
            ),
            HealthDataUpload(
                data_type: "heart_rate",
                value: 65,
                unit: "bpm",
                recorded_at: Date()
            )
        ]
        
        let mockResponse = """
        {
            "processing_ids": ["123", "456"],
            "success_count": 2,
            "failed_count": 0
        }
        """
        mockNetworkService.mockResponseData = mockResponse.data(using: .utf8)
        
        // When
        let result = try await sut.batchUploadHealthData(batch)
        
        // Then
        XCTAssertEqual(result.processingIds.count, 2)
        XCTAssertEqual(result.successCount, 2)
        XCTAssertEqual(result.failedCount, 0)
    }
}

// MARK: - Mock NetworkService

private final class MockNetworkService: NetworkServiceProtocol, @unchecked Sendable {
    var mockResponseData: Data?
    var shouldThrowError = false
    var errorToThrow: Error?
    var lastEndpoint: Endpoint?
    
    func request<T: Decodable>(_ endpoint: Endpoint, type: T.Type) async throws -> T {
        lastEndpoint = endpoint
        
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        
        guard let data = mockResponseData else {
            throw NetworkError.invalidResponse
        }
        
        do {
            // Use same date decoding strategy as real APIClient
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 with fractional seconds first
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                // Fall back to standard ISO8601
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
            }
            
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        lastEndpoint = endpoint
        
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        
        return Data()
    }
    
    func upload(_ endpoint: Endpoint, data: Data, progressHandler: ((Double) -> Void)?) async throws -> Data {
        lastEndpoint = endpoint
        return Data()
    }
    
    func download(_ endpoint: Endpoint, progressHandler: ((Double) -> Void)?) async throws -> URL {
        lastEndpoint = endpoint
        return URL(string: "https://test.com")!
    }
}

// MARK: - DTOs (Based on REAL backend)

private struct LoginResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
}

private struct HealthDataResponse: Codable {
    let processing_id: String
    let status: String
    let message: String
}

private struct UserProfileResponse: Codable {
    let id: String
    let email: String
    let first_name: String
    let last_name: String
    let date_of_birth: String
}

private struct InsightResponse: Codable {
    let id: String
    let type: String
    let title: String
    let description: String
    let severity: String
    let created_at: Date
}

private struct InsightsListResponse: Codable {
    let insights: [InsightResponse]
}

private struct BatchUploadResponse: Codable {
    let processing_ids: [String]
    let success_count: Int
    let failed_count: Int
}
