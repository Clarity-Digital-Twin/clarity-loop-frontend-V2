//
//  HealthMetricRepositoryProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol defining health metric repository operations
//

import Foundation

/// Protocol for health metric data persistence operations
public protocol HealthMetricRepositoryProtocol: Sendable {
    /// Creates a new health metric
    func create(_ metric: HealthMetric) async throws -> HealthMetric
    
    /// Creates multiple health metrics in batch
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric]
    
    /// Finds a metric by ID
    func findById(_ id: UUID) async throws -> HealthMetric?
    
    /// Finds all metrics for a user
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric]
    
    /// Finds metrics for a user within a date range
    func findByUserIdAndDateRange(
        userId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric]
    
    /// Finds metrics by type for a user
    func findByUserIdAndType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> [HealthMetric]
    
    /// Updates an existing metric
    func update(_ metric: HealthMetric) async throws -> HealthMetric
    
    /// Deletes a metric by ID
    func delete(_ id: UUID) async throws
    
    /// Deletes all metrics for a user
    func deleteAllForUser(_ userId: UUID) async throws
    
    /// Gets the latest metric of a specific type for a user
    func getLatestByType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> HealthMetric?
}