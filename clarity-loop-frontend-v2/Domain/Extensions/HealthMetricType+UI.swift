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
        case .restingHeartRate: return "heart.text.square"
        case .walkingHeartRateAverage: return "figure.walk.motion"
        case .heartRateVariabilitySDNN: return "waveform.path.ecg.rectangle"
        case .vo2Max: return "speedometer"
        case .activeEnergyBurned: return "flame.circle"
        case .appleExerciseTime: return "figure.strengthtraining.traditional"
        case .appleStandTime: return "figure.stand"
        case .distanceWalkingRunning: return "figure.walk.diamond"
        case .distanceCycling: return "bicycle"
        case .flightsClimbed: return "stairs"
        case .stepCount: return "shoeprints.fill"
        case .workoutDuration: return "timer"
        case .basalBodyTemperature: return "thermometer.medium"
        case .bloodOxygen: return "lungs"
        case .electrocardiogram: return "waveform.path.ecg"
        case .forcedExpiratoryVolume1: return "lungs.fill"
        case .forcedVitalCapacity: return "wind.circle"
        case .inhalerUsage: return "medical.thermometer"
        case .peakExpiratoryFlowRate: return "wind"
        case .sixMinuteWalkTestDistance: return "figure.walk.arrival"
        case .stairAscentSpeed: return "figure.stairs"
        case .stairDescentSpeed: return "figure.stairs"
        case .walkingAsymmetryPercentage: return "figure.walk"
        case .walkingDoubleSupportPercentage: return "shoe.2"
        case .walkingSpeed: return "speedometer"
        case .walkingStepLength: return "ruler"
        case .deepSleep: return "moon.zzz.fill"
        case .remSleep: return "moon.stars.fill"
        case .lightSleep: return "moon.fill"
        case .awake: return "sun.max.fill"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
    
    /// Primary color for this health metric type
    var color: Color {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return .red
        case .steps, .stepCount, .walkingSpeed, .distanceWalkingRunning:
            return .green
        case .bloodPressureSystolic, .bloodPressureDiastolic, .electrocardiogram:
            return .purple
        case .bloodGlucose, .caloriesBurned, .activeEnergyBurned:
            return .orange
        case .weight, .height:
            return .blue
        case .bodyTemperature, .basalBodyTemperature:
            return .pink
        case .oxygenSaturation, .bloodOxygen, .vo2Max:
            return .cyan
        case .respiratoryRate, .forcedExpiratoryVolume1, .forcedVitalCapacity:
            return .teal
        case .sleepDuration, .deepSleep, .remSleep, .lightSleep:
            return .indigo
        case .waterIntake:
            return .blue
        case .exerciseDuration, .workoutDuration, .appleExerciseTime:
            return .green
        case .distanceCycling:
            return .mint
        case .flightsClimbed, .stairAscentSpeed, .stairDescentSpeed:
            return .brown
        default:
            return .gray
        }
    }
    
    /// Valid range for this metric type
    var validRange: (min: Double, max: Double) {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return (30, 220)
        case .steps, .stepCount:
            return (0, 100_000)
        case .bloodPressureSystolic:
            return (60, 200)
        case .bloodPressureDiastolic:
            return (40, 130)
        case .bloodGlucose:
            return (20, 600)
        case .weight:
            return (1, 500)
        case .height:
            return (30, 300)
        case .bodyTemperature, .basalBodyTemperature:
            return (35, 42)
        case .oxygenSaturation, .bloodOxygen:
            return (70, 100)
        case .respiratoryRate:
            return (8, 40)
        case .sleepDuration:
            return (0, 24)
        case .deepSleep, .remSleep, .lightSleep:
            return (0, 12)
        case .caloriesBurned, .activeEnergyBurned:
            return (0, 5000)
        case .waterIntake:
            return (0, 10000)
        case .exerciseDuration, .workoutDuration:
            return (0, 720)
        case .vo2Max:
            return (10, 80)
        case .heartRateVariabilitySDNN:
            return (0, 200)
        case .distanceWalkingRunning, .distanceCycling:
            return (0, 100)
        case .flightsClimbed:
            return (0, 500)
        case .walkingSpeed:
            return (0, 10)
        case .walkingStepLength:
            return (0, 200)
        case .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
            return (0, 100)
        case .sixMinuteWalkTestDistance:
            return (0, 1000)
        case .stairAscentSpeed, .stairDescentSpeed:
            return (0, 5)
        default:
            return (0, 1000)
        }
    }
}
