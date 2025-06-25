//
//  HealthMetricType.swift
//  clarity-loop-frontend-v2
//
//  Enumeration of health metric types
//

import Foundation

/// Types of health metrics that can be tracked
enum HealthMetricType: Codable, Equatable, CaseIterable {
    case heartRate
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case bloodGlucose
    case weight
    case height
    case bodyTemperature
    case oxygenSaturation
    case steps
    case sleepDuration
    case custom(String)
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .heartRate:
            return "Heart Rate"
        case .bloodPressureSystolic:
            return "Systolic Blood Pressure"
        case .bloodPressureDiastolic:
            return "Diastolic Blood Pressure"
        case .bloodGlucose:
            return "Blood Glucose"
        case .weight:
            return "Weight"
        case .height:
            return "Height"
        case .bodyTemperature:
            return "Body Temperature"
        case .oxygenSaturation:
            return "Oxygen Saturation"
        case .steps:
            return "Steps"
        case .sleepDuration:
            return "Sleep Duration"
        case .custom(let name):
            return name
        }
    }
    
    /// Default unit for this metric type
    var defaultUnit: String {
        switch self {
        case .heartRate:
            return "BPM"
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return "mmHg"
        case .bloodGlucose:
            return "mg/dL"
        case .weight:
            return "kg"
        case .height:
            return "cm"
        case .bodyTemperature:
            return "°C"
        case .oxygenSaturation:
            return "%"
        case .steps:
            return "steps"
        case .sleepDuration:
            return "hours"
        case .custom:
            return "units"
        }
    }
    
    /// Valid range for this metric type
    var validRange: ClosedRange<Double>? {
        switch self {
        case .heartRate:
            return 40...200
        case .bloodPressureSystolic:
            return 70...200
        case .bloodPressureDiastolic:
            return 40...130
        case .bloodGlucose:
            return 50...400
        case .weight:
            return 20...300
        case .height:
            return 50...250
        case .bodyTemperature:
            return 35...42
        case .oxygenSaturation:
            return 70...100
        case .steps:
            return 0...100000
        case .sleepDuration:
            return 0...24
        case .custom:
            return nil
        }
    }
    
    // MARK: - CaseIterable conformance
    
    static var allCases: [HealthMetricType] {
        [
            .heartRate,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bloodGlucose,
            .weight,
            .height,
            .bodyTemperature,
            .oxygenSaturation,
            .steps,
            .sleepDuration
        ]
    }
}