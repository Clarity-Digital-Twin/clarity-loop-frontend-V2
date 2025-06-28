//
//  HealthMetricDTO.swift
//  clarity-loop-frontend-v2
//
//  Data Transfer Object for HealthMetric entity
//

import Foundation
import ClarityDomain

/// DTO for HealthMetric data transfer between API and domain
struct HealthMetricDTO: Codable {
    let id: String
    let userId: String
    let type: String
    let value: Double
    let unit: String
    let recordedAt: String
    let source: String?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type = "metric_type"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
        case notes
    }
}

// MARK: - Domain Mapping

extension HealthMetricDTO {
    /// Convert DTO to Domain Entity
    func toDomainModel() throws -> HealthMetric {
        guard let uuid = UUID(uuidString: id) else {
            throw DTOError.invalidUUID(id)
        }
        
        guard let userUuid = UUID(uuidString: userId) else {
            throw DTOError.invalidUUID(userId)
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let recordedDate = dateFormatter.date(from: recordedAt) else {
            throw DTOError.invalidDate(recordedAt)
        }
        
        let metricType = mapDTOTypeToMetricType(type)
        let metricSource = source.flatMap { HealthMetricSource(rawValue: $0) }
        
        return HealthMetric(
            id: uuid,
            userId: userUuid,
            type: metricType,
            value: value,
            unit: unit,
            recordedAt: recordedDate,
            source: metricSource,
            notes: notes
        )
    }
    
    private func mapDTOTypeToMetricType(_ dtoType: String) -> HealthMetricType {
        switch dtoType {
        case "heart_rate":
            return .heartRate
        case "blood_pressure_systolic":
            return .bloodPressureSystolic
        case "blood_pressure_diastolic":
            return .bloodPressureDiastolic
        case "blood_glucose":
            return .bloodGlucose
        case "weight":
            return .weight
        case "height":
            return .height
        case "body_temperature":
            return .bodyTemperature
        case "oxygen_saturation":
            return .oxygenSaturation
        case "steps":
            return .steps
        case "sleep_duration":
            return .sleepDuration
        case "respiratory_rate":
            return .respiratoryRate
        case "calories_burned":
            return .caloriesBurned
        case "water_intake":
            return .waterIntake
        case "exercise_duration":
            return .exerciseDuration
        default:
            return .custom(dtoType.replacingOccurrences(of: "_", with: " ").capitalized)
        }
    }
}

extension HealthMetric {
    /// Convert Domain Entity to DTO
    func toDTO() -> HealthMetricDTO {
        let dateFormatter = ISO8601DateFormatter()
        
        let dtoType: String
        switch type {
        case .heartRate:
            dtoType = "heart_rate"
        case .bloodPressureSystolic:
            dtoType = "blood_pressure_systolic"
        case .bloodPressureDiastolic:
            dtoType = "blood_pressure_diastolic"
        case .bloodGlucose:
            dtoType = "blood_glucose"
        case .weight:
            dtoType = "weight"
        case .height:
            dtoType = "height"
        case .bodyTemperature:
            dtoType = "body_temperature"
        case .oxygenSaturation:
            dtoType = "oxygen_saturation"
        case .steps:
            dtoType = "steps"
        case .sleepDuration:
            dtoType = "sleep_duration"
        case .respiratoryRate:
            dtoType = "respiratory_rate"
        case .caloriesBurned:
            dtoType = "calories_burned"
        case .waterIntake:
            dtoType = "water_intake"
        case .exerciseDuration:
            dtoType = "exercise_duration"
        case .custom(let name):
            dtoType = name.lowercased().replacingOccurrences(of: " ", with: "_")
        }
        
        return HealthMetricDTO(
            id: id.uuidString,
            userId: userId.uuidString,
            type: dtoType,
            value: value,
            unit: unit,
            recordedAt: dateFormatter.string(from: recordedAt),
            source: source?.rawValue,
            notes: notes
        )
    }
}
