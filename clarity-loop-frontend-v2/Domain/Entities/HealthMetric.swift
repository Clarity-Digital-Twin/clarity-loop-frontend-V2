//
//  HealthMetric.swift
//  clarity-loop-frontend-v2
//
//  Health metric domain entity
//

import Foundation

/// Domain entity representing a health metric
@Observable
final class HealthMetric: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: HealthMetricType
    let value: Double
    let unit: String
    let recordedAt: Date
    var source: HealthMetricSource?
    var notes: String?
    
    /// Validates if the metric value is within acceptable range
    var isValueValid: Bool {
        guard let range = type.validRange else { return true }
        return range.contains(value)
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        type: HealthMetricType,
        value: Double,
        unit: String,
        recordedAt: Date,
        source: HealthMetricSource? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
        self.source = source
        self.notes = notes
    }
    
    // MARK: - Static Methods
    
    /// Calculates BMI from weight and height metrics
    static func calculateBMI(weight: HealthMetric, height: HealthMetric) -> Double? {
        guard weight.type == .weight,
              height.type == .height else { return nil }
        
        // Convert height from cm to meters
        let heightInMeters = height.value / 100
        
        // BMI = weight (kg) / height² (m²)
        return weight.value / (heightInMeters * heightInMeters)
    }
}
