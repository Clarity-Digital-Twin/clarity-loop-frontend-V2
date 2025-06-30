//
//  EncryptedNetworkIntegrationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Integration tests for encrypted network communication
//

import Testing
import Foundation
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

@Suite("Encrypted Network Integration Tests")
struct EncryptedNetworkIntegrationTests {
    
    @Test("Full encryption flow: metric creation to network transmission")
    func testEndToEndEncryption() async throws {
        // Setup
        let secureStorage = SecureStorage()
        let encryptionInterceptor = EncryptedRequestInterceptor(secureStorage: secureStorage)
        // Configure mock to capture the request
        let requestCapture = RequestCapture()
        let mockSession = MockURLSession(onDataTask: { request in
            Task { await requestCapture.capture(request) }
            
            // Return mock encrypted response
            let responsePayload = EncryptedHealthPayload(
                encryptedData: "mock-encrypted-data",
                algorithm: "AES-GCM-256",
                keyId: "test-key-id",
                timestamp: Date(),
                nonce: "mock-nonce"
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let responseData = try! encoder.encode(responsePayload)
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/vnd.clarity.encrypted+json"
                ]
            )!
            
            return (responseData, response)
        })
        
        let networkService = NetworkService(
            baseURL: URL(string: "https://api.clarity.health")!,
            session: mockSession,
            authService: EncryptionTestMockAuthService(),
            tokenStorage: EncryptionTestMockTokenStorage(),
            interceptors: [encryptionInterceptor]
        )
        
        let apiClient = APIClient(networkService: networkService)
        
        // Create health metric
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .bloodPressureSystolic,
            value: 120.0,
            unit: "mmHg",
            recordedAt: Date(),
            source: .manual,
            notes: "Morning reading"
        )
        
        // Create health data upload from metric
        let healthData = HealthDataUpload(
            data_type: metric.type.rawValue,
            value: metric.value,
            unit: metric.unit,
            recorded_at: metric.recordedAt
        )
        
        // Upload health data via API
        _ = try? await apiClient.uploadHealthData(healthData)
        
        // Verify encryption was applied
        let capturedRequest = await requestCapture.getRequest()
        #expect(capturedRequest != nil)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/vnd.clarity.encrypted+json")
        #expect(capturedRequest?.value(forHTTPHeaderField: "X-Encryption-Algorithm") == "AES-GCM-256")
        
        // Verify body was encrypted
        if let bodyData = capturedRequest?.httpBody {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Should be able to decode as encrypted payload
            let encryptedDTO = try? decoder.decode(EncryptedCreateHealthMetricDTO.self, from: bodyData)
            #expect(encryptedDTO != nil)
            #expect(encryptedDTO?.encryptedPayload.algorithm == "AES-GCM-256")
        }
    }
    
    @Test("Batch health metrics should be encrypted individually")
    func testBatchEncryption() async throws {
        let secureStorage = SecureStorage()
        let interceptor = EncryptedRequestInterceptor(secureStorage: secureStorage)
        
        // Create multiple metrics
        let metrics = [
            HealthMetric(id: UUID(), userId: UUID(), type: .heartRate, value: 72, unit: "bpm", recordedAt: Date()),
            HealthMetric(id: UUID(), userId: UUID(), type: .steps, value: 5000, unit: "steps", recordedAt: Date()),
            HealthMetric(id: UUID(), userId: UUID(), type: .weight, value: 70.5, unit: "kg", recordedAt: Date())
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metricsData = try encoder.encode(metrics)
        
        var request = URLRequest(url: URL(string: "https://api.clarity.health/api/v1/health-metrics/batch")!)
        request.httpMethod = "POST"
        request.httpBody = metricsData
        
        // Apply encryption
        try await interceptor.intercept(&request)
        
        // Verify each metric was encrypted
        if let bodyData = request.httpBody {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let payloads = try decoder.decode([EncryptedHealthPayload].self, from: bodyData)
            #expect(payloads.count == metrics.count)
            
            // Each should have unique encryption
            let encryptedData = Set(payloads.map { $0.encryptedData })
            #expect(encryptedData.count == metrics.count) // All different
        }
    }
    
    @Test("Non-sensitive endpoints should not be encrypted")
    func testSelectiveEncryption() async throws {
        let secureStorage = SecureStorage()
        let interceptor = EncryptedRequestInterceptor(secureStorage: secureStorage)
        
        // Create a user profile update (non-sensitive)
        let profileData = Data("{\"firstName\":\"John\",\"lastName\":\"Doe\"}".utf8)
        
        var request = URLRequest(url: URL(string: "https://api.clarity.health/api/v1/users/profile")!)
        request.httpMethod = "PUT"
        request.httpBody = profileData
        
        // Apply interceptor
        try await interceptor.intercept(&request)
        
        // Should not be encrypted
        #expect(request.httpBody == profileData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }
    
    @Test("Decryption should handle server responses correctly")
    func testResponseDecryption() async throws {
        let secureStorage = SecureStorage()
        let responseHandler = EncryptedResponseHandler(secureStorage: secureStorage)
        
        // Create encrypted response from server
        let originalMetric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .oxygenSaturation,
            value: 98.0,
            unit: "%",
            recordedAt: Date()
        )
        
        let payload = try await secureStorage.prepareForTransmission(originalMetric)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encryptedData = try encoder.encode(payload)
        
        let response = HTTPURLResponse(
            url: URL(string: "https://api.clarity.health/api/v1/health-metrics/123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/vnd.clarity.encrypted+json"]
        )!
        
        // Decrypt response
        let decryptedData = try await responseHandler.handleResponse(encryptedData, response: response)
        
        // Should get back original metric
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decryptedMetric = try decoder.decode(HealthMetric.self, from: decryptedData)
        
        #expect(decryptedMetric.id == originalMetric.id)
        #expect(decryptedMetric.value == originalMetric.value)
    }
}

// MARK: - Mock URLSession

private final class MockURLSession: URLSessionProtocol {
    let onDataTask: (@Sendable (URLRequest) throws -> (Data, URLResponse))?
    
    init(onDataTask: (@Sendable (URLRequest) throws -> (Data, URLResponse))? = nil) {
        self.onDataTask = onDataTask
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let onDataTask = onDataTask else {
            throw URLError(.badServerResponse)
        }
        return try onDataTask(request)
    }
}

// MARK: - Mock Services

private final class EncryptionTestMockAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> AuthToken {
        return AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
    }
    
    func logout() async throws {}
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        return AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
    }
    
    func getCurrentUser() async throws -> User? {
        return nil
    }
}

private final class EncryptionTestMockTokenStorage: TokenStorageProtocol, @unchecked Sendable {
    private var token: AuthToken?
    
    func saveToken(_ token: AuthToken) async throws {
        self.token = token
    }
    
    func getToken() async throws -> AuthToken? {
        return token
    }
    
    func getAccessToken() async throws -> String? {
        return token?.accessToken
    }
    
    func clearToken() async throws {
        token = nil
    }
    
    func getRefreshToken() async throws -> String? {
        return token?.refreshToken
    }
}

// MARK: - Request Capture Actor

private actor RequestCapture {
    private var capturedRequest: URLRequest?
    
    func capture(_ request: URLRequest) {
        self.capturedRequest = request
    }
    
    func getRequest() -> URLRequest? {
        return capturedRequest
    }
}
