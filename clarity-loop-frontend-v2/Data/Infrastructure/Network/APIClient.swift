//
//  APIClient.swift
//  clarity-loop-frontend-v2
//
//  REAL API Client - Connected to ACTUAL backend at clarity.novamindnyc.com
//  NO MORE FUCKING MOCKS!
//

import Foundation
import ClarityDomain

/// REAL API Client that connects to the ACTUAL backend
public final class APIClient: APIClientProtocol {
    
    // MARK: - Properties
    
    private let networkService: NetworkServiceProtocol
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    // MARK: - Initialization
    
    public init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        
        // Configure JSON decoder for backend format
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom { decoder in
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
        
        // Configure JSON encoder
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Authentication
    
    public func login(email: String, password: String) async throws -> AuthToken {
        let endpoint = Endpoint(
            path: "/api/v1/auth/login",
            method: .post,
            body: try? JSONEncoder().encode(LoginRequest(email: email, password: password)),
            requiresAuth: false
        )
        
        let response: LoginResponse = try await networkService.request(endpoint, type: LoginResponse.self)
        
        return AuthToken(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresIn: response.expires_in
        )
    }
    
    public func logout() async throws {
        let endpoint = Endpoint(
            path: "/api/v1/auth/logout",
            method: .post,
            requiresAuth: true
        )
        
        _ = try await networkService.request(endpoint)
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        let endpoint = Endpoint(
            path: "/api/v1/auth/refresh",
            method: .post,
            body: try? JSONEncoder().encode(RefreshRequest(refresh_token: refreshToken)),
            requiresAuth: false
        )
        
        let response: LoginResponse = try await networkService.request(endpoint, type: LoginResponse.self)
        
        return AuthToken(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresIn: response.expires_in
        )
    }
    
    public func getCurrentUser() async throws -> User {
        let endpoint = Endpoint(
            path: "/api/v1/auth/me",
            method: .get,
            requiresAuth: true
        )
        
        let response: UserProfileResponse = try await networkService.request(endpoint, type: UserProfileResponse.self)
        
        return User(
            id: UUID(uuidString: response.id) ?? UUID(),
            email: response.email,
            firstName: response.first_name,
            lastName: response.last_name,
            dateOfBirth: ISO8601DateFormatter().date(from: response.date_of_birth)
        )
    }
    
    // MARK: - Health Data
    
    public func uploadHealthData(_ data: HealthDataUpload) async throws -> String {
        let endpoint = Endpoint(
            path: "/api/v1/health-data/",
            method: .post,
            body: try? JSONEncoder().encode(data),
            requiresAuth: true
        )
        
        let response: HealthDataResponse = try await networkService.request(endpoint, type: HealthDataResponse.self)
        return response.processing_id
    }
    
    public func batchUploadHealthData(_ batch: [HealthDataUpload]) async throws -> BatchUploadResult {
        let endpoint = Endpoint(
            path: "/api/v1/health-data/batch",
            method: .post,
            body: try? JSONEncoder().encode(BatchUploadRequest(records: batch)),
            requiresAuth: true
        )
        
        let response: BatchUploadResponse = try await networkService.request(endpoint, type: BatchUploadResponse.self)
        
        return BatchUploadResult(
            processingIds: response.processing_ids,
            successCount: response.success_count,
            failedCount: response.failed_count
        )
    }
    
    public func getHealthDataStatus(processingId: String) async throws -> HealthDataStatus {
        let endpoint = Endpoint(
            path: "/api/v1/health-data/processing/\(processingId)",
            method: .get,
            requiresAuth: true
        )
        
        let response: HealthDataStatusResponse = try await networkService.request(endpoint, type: HealthDataStatusResponse.self)
        
        return HealthDataStatus(
            processingId: response.processing_id,
            status: response.status,
            message: response.message
        )
    }
    
    // MARK: - Insights
    
    public func getInsights() async throws -> [Insight] {
        let endpoint = Endpoint(
            path: "/api/v1/insights/",
            method: .get,
            requiresAuth: true
        )
        
        let response: InsightsListResponse = try await networkService.request(endpoint, type: InsightsListResponse.self)
        
        return response.insights.map { insight in
            Insight(
                id: insight.id,
                type: InsightType(rawValue: insight.type) ?? .general,
                title: insight.title,
                description: insight.description,
                severity: InsightSeverity(rawValue: insight.severity) ?? .low,
                createdAt: insight.created_at
            )
        }
    }
    
    public func getInsight(id: String) async throws -> Insight {
        let endpoint = Endpoint(
            path: "/api/v1/insights/\(id)",
            method: .get,
            requiresAuth: true
        )
        
        let response: InsightResponse = try await networkService.request(endpoint, type: InsightResponse.self)
        
        return Insight(
            id: response.id,
            type: InsightType(rawValue: response.type) ?? .general,
            title: response.title,
            description: response.description,
            severity: InsightSeverity(rawValue: response.severity) ?? .low,
            createdAt: response.created_at
        )
    }
    
    // MARK: - Metrics
    
    public func getMetrics() async throws -> Metrics {
        let endpoint = Endpoint(
            path: "/api/v1/metrics/metrics",
            method: .get,
            requiresAuth: true
        )
        
        let response: MetricsResponse = try await networkService.request(endpoint, type: MetricsResponse.self)
        
        return Metrics(
            totalUsers: response.total_users,
            activeUsers: response.active_users,
            totalHealthRecords: response.total_health_records,
            averageRecordsPerUser: response.average_records_per_user
        )
    }
    
    // MARK: - APIClientProtocol Methods (Legacy support)
    
    public func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T {
        let queryItems = parameters?.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let apiEndpoint = Endpoint(
            path: endpoint,
            method: .get,
            queryItems: queryItems,
            requiresAuth: true
        )
        
        return try await networkService.request(apiEndpoint, type: T.self)
    }
    
    public func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        let apiEndpoint = Endpoint(
            path: endpoint,
            method: .post,
            body: try? JSONEncoder().encode(body),
            requiresAuth: true
        )
        
        return try await networkService.request(apiEndpoint, type: T.self)
    }
    
    public func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        let apiEndpoint = Endpoint(
            path: endpoint,
            method: .put,
            body: try? JSONEncoder().encode(body),
            requiresAuth: true
        )
        
        return try await networkService.request(apiEndpoint, type: T.self)
    }
    
    public func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        let apiEndpoint = Endpoint(
            path: endpoint,
            method: .delete,
            requiresAuth: true
        )
        
        return try await networkService.request(apiEndpoint, type: T.self)
    }
    
    public func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        let endpoint = Endpoint(
            path: "/api/v1/\(String(describing: type).lowercased())s/\(id)",
            method: .delete,
            requiresAuth: true
        )
        
        _ = try await networkService.request(endpoint)
    }
}

// MARK: - Request DTOs

private struct LoginRequest: Codable {
    let email: String
    let password: String
}

private struct RefreshRequest: Codable {
    let refresh_token: String
}

private struct BatchUploadRequest: Codable {
    let records: [HealthDataUpload]
}

// MARK: - Response DTOs (FROM REAL BACKEND!)

private struct LoginResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
}

private struct UserProfileResponse: Codable {
    let id: String
    let email: String
    let first_name: String
    let last_name: String
    let date_of_birth: String
}

private struct HealthDataResponse: Codable {
    let processing_id: String
    let status: String
    let message: String
}

private struct HealthDataStatusResponse: Codable {
    let processing_id: String
    let status: String
    let message: String?
}

private struct BatchUploadResponse: Codable {
    let processing_ids: [String]
    let success_count: Int
    let failed_count: Int
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

private struct MetricsResponse: Codable {
    let total_users: Int
    let active_users: Int
    let total_health_records: Int
    let average_records_per_user: Double
}

// MARK: - Domain Model Extensions

public struct HealthDataUpload: Codable {
    public let data_type: String
    public let value: Double
    public let unit: String
    public let recorded_at: Date
    
    public init(data_type: String, value: Double, unit: String, recorded_at: Date) {
        self.data_type = data_type
        self.value = value
        self.unit = unit
        self.recorded_at = recorded_at
    }
}

public struct BatchUploadResult {
    public let processingIds: [String]
    public let successCount: Int
    public let failedCount: Int
}

public struct HealthDataStatus {
    public let processingId: String
    public let status: String
    public let message: String?
}

public struct Insight {
    public let id: String
    public let type: InsightType
    public let title: String
    public let description: String
    public let severity: InsightSeverity
    public let createdAt: Date
}

public enum InsightType: String {
    case anomaly
    case trend
    case recommendation
    case general
}

public enum InsightSeverity: String {
    case low
    case medium
    case high
    case critical
}

public struct Metrics {
    public let totalUsers: Int
    public let activeUsers: Int
    public let totalHealthRecords: Int
    public let averageRecordsPerUser: Double
}
