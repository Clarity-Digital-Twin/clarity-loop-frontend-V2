//
//  HealthMetricType.swift
//  clarity-loop-frontend-v2
//
//  Enumeration of health metric types
//

import Foundation

/// Types of health metrics that can be tracked
public enum HealthMetricType: Codable, Equatable, CaseIterable, Sendable, Hashable {
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
    case respiratoryRate
    case caloriesBurned
    case waterIntake
    case exerciseDuration
    case custom(String)
    
    /// Human-readable display name
    public var displayName: String {
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
        case .respiratoryRate:
            return "Respiratory Rate"
        case .caloriesBurned:
            return "Calories Burned"
        case .waterIntake:
            return "Water Intake"
        case .exerciseDuration:
            return "Exercise Duration"
        case .custom(let name):
            return name
        }
    }
    
    /// Default unit for this metric type
    public var defaultUnit: String {
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
        case .respiratoryRate:
            return "breaths/min"
        case .caloriesBurned:
            return "kcal"
        case .waterIntake:
            return "L"
        case .exerciseDuration:
            return "min"
        case .custom:
            return "units"
        }
    }
    
    /// Valid range for this metric type
    public var validRange: ClosedRange<Double>? {
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
        case .respiratoryRate:
            return 8...30
        case .caloriesBurned:
            return 0...10000
        case .waterIntake:
            return 0...10
        case .exerciseDuration:
            return 0...600
        case .custom:
            return nil
        }
    }
    
    /// String representation for persistence
    public var rawValue: String {
        switch self {
        case .heartRate:
            return "heart_rate"
        case .bloodPressureSystolic:
            return "blood_pressure_systolic"
        case .bloodPressureDiastolic:
            return "blood_pressure_diastolic"
        case .bloodGlucose:
            return "blood_glucose"
        case .weight:
            return "weight"
        case .height:
            return "height"
        case .bodyTemperature:
            return "body_temperature"
        case .oxygenSaturation:
            return "oxygen_saturation"
        case .steps:
            return "steps"
        case .sleepDuration:
            return "sleep_duration"
        case .respiratoryRate:
            return "respiratory_rate"
        case .caloriesBurned:
            return "calories_burned"
        case .waterIntake:
            return "water_intake"
        case .exerciseDuration:
            return "exercise_duration"
        case .custom(let name):
            return name
        }
    }
    
    /// Initialize from string representation
    public init?(rawValue: String) {
        switch rawValue {
        case "heart_rate":
            self = .heartRate
        case "blood_pressure_systolic":
            self = .bloodPressureSystolic
        case "blood_pressure_diastolic":
            self = .bloodPressureDiastolic
        case "blood_glucose":
            self = .bloodGlucose
        case "weight":
            self = .weight
        case "height":
            self = .height
        case "body_temperature":
            self = .bodyTemperature
        case "oxygen_saturation":
            self = .oxygenSaturation
        case "steps":
            self = .steps
        case "sleep_duration":
            self = .sleepDuration
        case "respiratory_rate":
            self = .respiratoryRate
        case "calories_burned":
            self = .caloriesBurned
        case "water_intake":
            self = .waterIntake
        case "exercise_duration":
            self = .exerciseDuration
        default:
            self = .custom(rawValue)
        }
    }
    
    // MARK: - CaseIterable conformance
    
    public static var allCases: [HealthMetricType] {
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
            .sleepDuration,
            .respiratoryRate,
            .caloriesBurned,
            .waterIntake,
            .exerciseDuration
        ]
    }
}
