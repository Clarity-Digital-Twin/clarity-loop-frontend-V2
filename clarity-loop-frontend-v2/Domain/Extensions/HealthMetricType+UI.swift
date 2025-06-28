//
//  HealthMetricType+UI.swift
//  clarity-loop-frontend-v2
//
//  UI-specific extensions for HealthMetricType
//

import SwiftUI
import ClarityDomain

// MARK: - UI Properties
public extension HealthMetricType {
    
    /// SF Symbol icon for this health metric type
    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .steps: return "figure.walk"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "waveform.path.ecg"
        case .bloodGlucose: return "drop.fill"
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        case .bodyTemperature: return "thermometer"
        case .oxygenSaturation: return "lungs.fill"
        case .respiratoryRate: return "wind"
        case .sleepDuration: return "bed.double.fill"
        case .caloriesBurned: return "flame.fill"
        case .waterIntake: return "drop.triangle.fill"
        case .exerciseDuration: return "figure.run"
        case .custom: return "chart.line.uptrend.xyaxis"
        }
    }
    
    /// Primary color for this health metric type
    var color: Color {
        switch self {
        case .heartRate:
            return .red
        case .steps:
            return .green
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return .purple
        case .bloodGlucose, .caloriesBurned:
            return .orange
        case .weight, .height:
            return .blue
        case .bodyTemperature:
            return .pink
        case .oxygenSaturation:
            return .cyan
        case .respiratoryRate:
            return .teal
        case .sleepDuration:
            return .indigo
        case .waterIntake:
            return .blue
        case .exerciseDuration:
            return .green
        case .custom:
            return .gray
        }
    }
}
