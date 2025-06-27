//
//  HealthMetric.swift
//  clarity-loop-frontend-v2
//
//  Health metric domain entity
//

import Foundation

/// Domain entity representing a health metric measurement
///
/// The HealthMetric entity captures individual health data points such as
/// steps, heart rate, blood pressure, etc. It follows Domain-Driven Design
/// principles and provides business logic for health data validation.
public struct HealthMetric: Entity, Codable, Equatable, Hashable, Sendable {
    // MARK: - Entity Protocol Requirements
    
    public let id: UUID
    public let createdAt: Date
    public let updatedAt: Date
    
    // MARK: - Health Metric Properties
    
    /// ID of the user who owns this metric
    public let userId: UUID
    
    /// Type of health metric (steps, heart rate, etc.)
    public let type: HealthMetricType
    
    /// Numeric value of the measurement
    public let value: Double
    
    /// Unit of measurement (e.g., "steps", "bpm", "kg")
    public let unit: String
    
    /// When the metric was recorded (may differ from createdAt)
    public let recordedAt: Date
    
    /// Source of the metric (manual entry, device sync, etc.)
    public let source: HealthMetricSource?
    
    /// Optional notes or context about the measurement
    public let notes: String?
    
    // MARK: - Computed Properties
    
    /// Validates if the metric value is within acceptable range
    public var isValueValid: Bool {
        guard let range = type.validRange else { return true }
        return range.contains(value)
    }
    
    /// Human-readable formatted value with unit
    public var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = type.decimalPlaces
        
        let formattedNumber = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formattedNumber) \(unit)"
    }
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        userId: UUID,
        type: HealthMetricType,
        value: Double,
        unit: String,
        recordedAt: Date,
        source: HealthMetricSource? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
        self.source = source
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
    
    // MARK: - Methods
    
    /// Creates a new HealthMetric instance with updated value
    public func withUpdatedValue(_ newValue: Double, notes: String? = nil) -> HealthMetric {
        HealthMetric(
            id: id,
            userId: userId,
            type: type,
            value: newValue,
            unit: unit,
            recordedAt: recordedAt,
            source: source,
            notes: notes ?? self.notes,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    // MARK: - Static Methods
    
    /// Calculates BMI from weight and height metrics
    public static func calculateBMI(weight: HealthMetric, height: HealthMetric) -> Double? {
        guard weight.type == .weight,
              height.type == .height else { return nil }
        
        // Convert height from cm to meters
        let heightInMeters = height.value / 100
        
        // BMI = weight (kg) / height² (m²)
        return weight.value / (heightInMeters * heightInMeters)
    }
    
    /// Groups metrics by date for chart display
    public static func groupByDate(_ metrics: [HealthMetric]) -> [Date: [HealthMetric]] {
        Dictionary(grouping: metrics) { metric in
            Calendar.current.startOfDay(for: metric.recordedAt)
        }
    }
}

// MARK: - Test Support

#if DEBUG
public extension HealthMetric {
    /// Creates a mock health metric for testing
    static func mock(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        type: HealthMetricType = .steps,
        value: Double = 10000,
        unit: String = "steps",
        recordedAt: Date = Date(),
        source: HealthMetricSource? = .manual,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) -> HealthMetric {
        HealthMetric(
            id: id,
            userId: userId,
            type: type,
            value: value,
            unit: unit,
            recordedAt: recordedAt,
            source: source,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
#endif

// MARK: - HealthMetricType Extensions

public extension HealthMetricType {
    /// Number of decimal places to display for this metric type
    var decimalPlaces: Int {
        switch self {
        case .steps, .heartRate, .bloodPressureSystolic, .bloodPressureDiastolic,
             .oxygenSaturation, .respiratoryRate, .caloriesBurned, .exerciseDuration:
            return 0
        case .weight, .height, .bodyTemperature, .bloodGlucose, .waterIntake:
            return 1
        case .sleepDuration:
            return 1
        case .custom:
            return 2
        }
    }
}