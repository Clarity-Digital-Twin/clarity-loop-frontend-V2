//
//  AddMetricViewModel.swift
//  clarity-loop-frontend-v2
//
//  ViewModel for adding new health metrics
//

import SwiftUI
import ClarityDomain
import ClarityCore
import ClarityData

@MainActor
@Observable
public final class AddMetricViewModel {
    
    // MARK: - Properties
    
    private let repository: HealthMetricRepositoryProtocol
    private let apiClient: APIClient
    private let userId: UUID
    
    // Form state
    public var selectedMetricType: HealthMetricType = .heartRate
    public var value: String = ""
    public var notes: String = ""
    public var recordedAt = Date()
    
    // UI state
    public var isSubmitting: Bool = false
    public var errorMessage: String?
    public var validationErrors: [String] = []
    
    // MARK: - Initialization
    
    public init(
        repository: HealthMetricRepositoryProtocol,
        apiClient: APIClient,
        userId: UUID
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.userId = userId
    }
    
    // MARK: - Public Methods
    
    /// Validate form inputs
    @discardableResult
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate value presence
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Value is required")
        } else {
            // Validate numeric value
            if selectedMetricType == .bloodPressureSystolic || selectedMetricType == .bloodPressureDiastolic {
                // Blood pressure validation - these are separate metrics
                guard let numericValue = Double(value) else {
                    errors.append("Value must be a valid number")
                    validationErrors = errors
                    return errors
                }
                
                // Validate range based on metric type
                if let range = selectedMetricType.validRange {
                    if numericValue < range.lowerBound || numericValue > range.upperBound {
                        let lower = Int(range.lowerBound)
                        let upper = Int(range.upperBound)
                        let unit = selectedMetricType.defaultUnit
                        errors.append("\(selectedMetricType.displayName) must be between \(lower) and \(upper) \(unit)")
                    }
                }
            } else {
                // Most metrics need a single number
                guard let numericValue = Double(value) else {
                    errors.append("Value must be a valid number")
                    validationErrors = errors
                    return errors
                }
                
                // Validate range based on metric type
                if let range = selectedMetricType.validRange {
                    if numericValue < range.lowerBound || numericValue > range.upperBound {
                        let lower = Int(range.lowerBound)
                        let upper = Int(range.upperBound)
                        let unit = selectedMetricType.defaultUnit
                        errors.append("\(selectedMetricType.displayName) must be between \(lower) and \(upper) \(unit)")
                    }
                }
            }
        }
        
        // Validate date
        if recordedAt > Date() {
            errors.append("Date cannot be in the future")
        }
        
        validationErrors = errors
        return errors
    }
    
    /// Submit the metric
    public func submitMetric() async -> Bool {
        // Prevent double submission
        guard !isSubmitting else { return false }
        
        // Clear previous errors
        errorMessage = nil
        
        // Validate
        let errors = validate()
        guard errors.isEmpty else { return false }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            // Parse value based on type
            let numericValue = Double(value) ?? 0
            
            // Create health data upload
            let uploadData = HealthDataUpload(
                data_type: selectedMetricType.apiDataType,
                value: numericValue,
                unit: selectedMetricType.defaultUnit,
                recorded_at: recordedAt
            )
            
            // Upload to API first
            _ = try await apiClient.uploadHealthData(uploadData)
            
            // Use the injected user ID
            
            // Create local metric
            let metric = HealthMetric(
                userId: userId,
                type: selectedMetricType,
                value: numericValue,
                unit: selectedMetricType.defaultUnit,
                recordedAt: recordedAt,
                source: .manual,
                notes: notes.isEmpty ? nil : notes
            )
            
            // Save locally
            _ = try await repository.create(metric)
            
            // Success - reset form
            resetForm()
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Reset form to initial state
    public func resetForm() {
        selectedMetricType = .heartRate
        value = ""
        notes = ""
        recordedAt = Date()
        errorMessage = nil
        validationErrors = []
    }
}

// MARK: - HealthMetricType Extensions

private extension HealthMetricType {
    /// API data type mapping
    var apiDataType: String {
        switch self {
        case .heartRate:
            return "heart_rate"
        case .steps:
            return "steps"
        case .bloodPressureSystolic:
            return "blood_pressure_systolic"
        case .bloodPressureDiastolic:
            return "blood_pressure_diastolic"
        case .bloodGlucose:
            return "blood_glucose"
        case .bodyTemperature:
            return "body_temperature"
        case .oxygenSaturation:
            return "oxygen_saturation"
        case .weight:
            return "weight"
        case .height:
            return "height"
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
}
