//
//  RecordHealthMetricUseCase.swift
//  clarity-loop-frontend-v2
//
//  Use case for recording health metrics
//

import Foundation

/// Use case for recording health metrics
final class RecordHealthMetricUseCase: Sendable {
    private let repository: HealthMetricRepositoryProtocol
    
    init(repository: HealthMetricRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Records a single health metric
    func execute(
        userId: UUID,
        type: HealthMetricType,
        value: Double,
        unit: String? = nil,
        source: HealthMetricSource = .manual,
        notes: String? = nil
    ) async throws -> HealthMetric {
        // Use default unit if not provided
        let finalUnit = unit ?? type.defaultUnit
        
        // Create the metric
        let metric = HealthMetric(
            userId: userId,
            type: type,
            value: value,
            unit: finalUnit,
            recordedAt: Date(),
            source: source,
            notes: notes
        )
        
        // Validate the metric
        try validateMetric(metric)
        
        // Save to repository
        return try await repository.create(metric)
    }
    
    /// Records multiple health metrics in batch
    func executeBatch(
        userId: UUID,
        metrics: [(type: HealthMetricType, value: Double, unit: String?, source: HealthMetricSource?, notes: String?)]
    ) async throws -> [HealthMetric] {
        let healthMetrics = metrics.map { metricData in
            HealthMetric(
                userId: userId,
                type: metricData.type,
                value: metricData.value,
                unit: metricData.unit ?? metricData.type.defaultUnit,
                recordedAt: Date(),
                source: metricData.source ?? .manual,
                notes: metricData.notes
            )
        }
        
        // Validate all metrics
        for metric in healthMetrics {
            try validateMetric(metric)
        }
        
        // Save batch
        return try await repository.createBatch(healthMetrics)
    }
    
    /// Checks if a metric is a duplicate within a time window
    func isDuplicateMetric(
        userId: UUID,
        type: HealthMetricType,
        value: Double,
        withinMinutes: Int = 5
    ) async throws -> Bool {
        let cutoffDate = Date().addingTimeInterval(-Double(withinMinutes * 60))
        let recentMetrics = try await repository.findByUserIdAndDateRange(
            userId: userId,
            startDate: cutoffDate,
            endDate: Date()
        )
        
        return recentMetrics.contains { metric in
            metric.type == type && metric.value == value
        }
    }
    
    // MARK: - Private
    
    private func validateMetric(_ metric: HealthMetric) throws {
        // Check if value is within valid range
        if !metric.isValueValid {
            throw ValidationError.outOfRange(
                field: metric.type.displayName,
                min: metric.type.validRange?.lowerBound,
                max: metric.type.validRange?.upperBound
            )
        }
        
        // Additional validation can be added here
        // For example: checking for reasonable time ranges,
        // validating units match the metric type, etc.
    }
}