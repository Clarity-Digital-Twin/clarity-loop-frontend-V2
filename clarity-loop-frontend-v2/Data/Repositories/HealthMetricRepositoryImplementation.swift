//
//  HealthMetricRepositoryImplementation.swift
//  clarity-loop-frontend-v2
//
//  Concrete implementation of HealthMetricRepository
//

import Foundation
import ClarityDomain

/// Concrete implementation of HealthMetricRepositoryProtocol
final class HealthMetricRepositoryImplementation: HealthMetricRepositoryProtocol {
    
    private let apiClient: APIClientProtocol
    private let persistence: PersistenceServiceProtocol
    
    init(apiClient: APIClientProtocol, persistence: PersistenceServiceProtocol) {
        self.apiClient = apiClient
        self.persistence = persistence
    }
    
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        // Convert to DTO and send to API
        let dto = metric.toDTO()
        let responseDTO: HealthMetricDTO = try await apiClient.post("/api/v1/health-metrics", body: dto)
        
        // Convert response back to domain model
        let createdMetric = try responseDTO.toDomainModel()
        
        // Save to local persistence
        try await persistence.save(createdMetric)
        
        return createdMetric
    }
    
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        // Convert all to DTOs
        let dtos = metrics.map { $0.toDTO() }
        
        // Send batch to API
        let request = BatchCreateRequest(metrics: dtos)
        let response: BatchCreateResponse = try await apiClient.post("/api/v1/health-metrics/batch", body: request)
        
        // Convert responses back to domain models
        let createdMetrics = try response.metrics.map { try $0.toDomainModel() }
        
        // Save all to local persistence
        for metric in createdMetrics {
            try await persistence.save(metric)
        }
        
        return createdMetrics
    }
    
    func findById(_ id: UUID) async throws -> HealthMetric? {
        // Check local cache first
        if let cachedMetric: HealthMetric = try await persistence.fetch(id) {
            return cachedMetric
        }
        
        // Fetch from API if not cached
        do {
            let dto: HealthMetricDTO = try await apiClient.get("/api/v1/health-metrics/\(id.uuidString)", parameters: nil)
            let metric = try dto.toDomainModel()
            
            // Cache the result
            try await persistence.save(metric)
            
            return metric
        } catch {
            return nil
        }
    }
    
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        // Fetch user's metrics from API
        let parameters = ["user_id": userId.uuidString]
        let response: MetricListResponse = try await apiClient.get("/api/v1/health-metrics", parameters: parameters)
        
        let metrics = try response.metrics.map { try $0.toDomainModel() }
        
        // Cache results
        for metric in metrics {
            try await persistence.save(metric)
        }
        
        return metrics
    }
    
    func findByUserIdAndDateRange(
        userId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        // First try to get from local cache
        let allMetrics: [HealthMetric] = try await persistence.fetchAll()
        
        let filteredMetrics = allMetrics.filter { metric in
            metric.userId == userId &&
            metric.recordedAt >= startDate &&
            metric.recordedAt <= endDate
        }
        
        // If we have local data, return it
        if !filteredMetrics.isEmpty {
            return filteredMetrics
        }
        
        // Otherwise fetch from API
        let dateFormatter = ISO8601DateFormatter()
        let parameters = [
            "user_id": userId.uuidString,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        
        let response: MetricListResponse = try await apiClient.get("/api/v1/health-metrics", parameters: parameters)
        let metrics = try response.metrics.map { try $0.toDomainModel() }
        
        // Cache results
        for metric in metrics {
            try await persistence.save(metric)
        }
        
        return metrics
    }
    
    func findByUserIdAndType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> [HealthMetric] {
        // Convert type to API format
        let typeString: String
        switch type {
        case .heartRate:
            typeString = "heart_rate"
        case .bloodPressureSystolic:
            typeString = "blood_pressure_systolic"
        case .bloodPressureDiastolic:
            typeString = "blood_pressure_diastolic"
        case .bloodGlucose:
            typeString = "blood_glucose"
        case .weight:
            typeString = "weight"
        case .height:
            typeString = "height"
        case .bodyTemperature:
            typeString = "body_temperature"
        case .oxygenSaturation:
            typeString = "oxygen_saturation"
        case .steps:
            typeString = "steps"
        case .sleepDuration:
            typeString = "sleep_duration"
        case .respiratoryRate:
            typeString = "respiratory_rate"
        case .caloriesBurned:
            typeString = "calories_burned"
        case .waterIntake:
            typeString = "water_intake"
        case .exerciseDuration:
            typeString = "exercise_duration"
        case .custom(let name):
            typeString = name.lowercased().replacingOccurrences(of: " ", with: "_")
        }
        
        let parameters = [
            "user_id": userId.uuidString,
            "type": typeString
        ]
        
        let response: MetricListResponse = try await apiClient.get("/api/v1/health-metrics", parameters: parameters)
        let metrics = try response.metrics.map { try $0.toDomainModel() }
        
        // Cache results
        for metric in metrics {
            try await persistence.save(metric)
        }
        
        return metrics
    }
    
    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        // Update via API
        let dto = metric.toDTO()
        let responseDTO: HealthMetricDTO = try await apiClient.put("/api/v1/health-metrics/\(metric.id.uuidString)", body: dto)
        
        let updatedMetric = try responseDTO.toDomainModel()
        
        // Update local cache
        try await persistence.save(updatedMetric)
        
        return updatedMetric
    }
    
    func delete(_ id: UUID) async throws {
        // Delete from API
        let _: VoidResponse = try await apiClient.delete("/api/v1/health-metrics/\(id.uuidString)")
        
        // Remove from local cache
        try await persistence.delete(type: HealthMetric.self, id: id)
    }
    
    func deleteAllForUser(_ userId: UUID) async throws {
        // Delete all metrics for user from API
        let _: VoidResponse = try await apiClient.delete("/api/v1/users/\(userId.uuidString)/health-metrics")
        
        // Remove from local cache
        let allMetrics = try await persistence.fetchAll() as [HealthMetric]
        let userMetrics = allMetrics.filter { $0.userId == userId }
        
        for metric in userMetrics {
            try await persistence.delete(type: HealthMetric.self, id: metric.id)
        }
    }
    
    func getLatestByType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> HealthMetric? {
        // Get all metrics of this type for the user
        let metrics = try await findByUserIdAndType(userId: userId, type: type)
        
        // Return the most recent one
        return metrics.max { $0.recordedAt < $1.recordedAt }
    }
    
    /// Sync pending metrics that were created offline
    func syncPendingMetrics() async throws -> Int {
        // In a real implementation, this would track metrics created offline
        // For now, return 0 as we don't have offline tracking yet
        return 0
    }
}

// MARK: - Request/Response Types

private struct BatchCreateRequest: Codable {
    let metrics: [HealthMetricDTO]
}

private struct BatchCreateResponse: Codable {
    let metrics: [HealthMetricDTO]
    let created: Int
}

private struct MetricListResponse: Codable {
    let metrics: [HealthMetricDTO]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case metrics = "data"
        case total
        case page
        case pageSize = "page_size"
    }
}

private struct VoidResponse: Codable {}