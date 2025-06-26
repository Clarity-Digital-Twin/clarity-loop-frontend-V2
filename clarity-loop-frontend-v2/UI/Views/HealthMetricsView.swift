//
//  HealthMetricsView.swift
//  clarity-loop-frontend-v2
//
//  View for entering and managing health metrics
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct HealthMetricsView: View {
    @State private var selectedMetricType: HealthMetricType = .heartRate
    @State private var metricValue: String = ""
    @State private var notes: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    @EnvironmentObject private var appState: AppState
    
    private let metricTypes: [HealthMetricType] = [
        .heartRate,
        .steps,
        .bloodPressureSystolic,
        .bloodPressureDiastolic,
        .bloodGlucose,
        .weight,
        .height,
        .bodyTemperature,
        .oxygenSaturation,
        .respiratoryRate,
        .sleepDuration,
        .caloriesBurned,
        .waterIntake,
        .exerciseDuration
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Metric Type Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metric Type")
                            .font(.headline)
                        
                        Menu {
                            ForEach(metricTypes, id: \.self) { type in
                                Button(type.displayName) {
                                    selectedMetricType = type
                                    metricValue = ""
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedMetricType.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Value Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Value")
                            .font(.headline)
                        
                        HStack {
                            TextField(placeholderText, text: $metricValue)
                                .keyboardType(keyboardType)
                                .textFieldStyle(.roundedBorder)
                            
                            Text(unitText)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes (Optional)")
                            .font(.headline)
                        
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Submit Button
                    Button(action: submitMetric) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Record Metric")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(submitButtonEnabled ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!submitButtonEnabled || isLoading)
                    
                    // Recent Entries
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Entries")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Recent entries will be displayed here")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("History") {
                        // Navigate to history
                    }
                }
            }
        }
        .alert("Metric Recorded", isPresented: $showingAlert) {
            Button("OK") {
                clearForm()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Properties
    
    private var placeholderText: String {
        switch selectedMetricType {
        case .heartRate: return "e.g., 72"
        case .steps: return "e.g., 10000"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "e.g., 120"
        case .bloodGlucose: return "e.g., 95"
        case .weight: return "e.g., 70.5"
        case .height: return "e.g., 175"
        case .bodyTemperature: return "e.g., 98.6"
        case .oxygenSaturation: return "e.g., 98"
        case .respiratoryRate: return "e.g., 16"
        case .sleepDuration: return "e.g., 8.0"
        case .caloriesBurned: return "e.g., 500"
        case .waterIntake: return "e.g., 2.5"
        case .exerciseDuration: return "e.g., 45"
        default: return "Enter value"
        }
    }
    
    private var unitText: String {
        selectedMetricType.unit
    }
    
    private var keyboardType: UIKeyboardType {
        switch selectedMetricType {
        case .steps, .caloriesBurned:
            return .numberPad
        default:
            return .decimalPad
        }
    }
    
    private var submitButtonEnabled: Bool {
        !metricValue.isEmpty && Double(metricValue) != nil
    }
    
    // MARK: - Actions
    
    private func submitMetric() {
        guard let value = Double(metricValue),
              let userId = appState.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let container = DIContainer.shared
                let repository = container.require(HealthMetricRepositoryProtocol.self)
                
                let metric = HealthMetric(
                    userId: userId,
                    type: selectedMetricType,
                    value: value,
                    unit: selectedMetricType.unit,
                    source: .manual,
                    notes: notes.isEmpty ? nil : notes
                )
                
                try await repository.create(metric)
                
                await MainActor.run {
                    alertMessage = "Successfully recorded \(selectedMetricType.displayName): \(value) \(unitText)"
                    showingAlert = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to record metric: \(error.localizedDescription)"
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func clearForm() {
        metricValue = ""
        notes = ""
    }
}

// MARK: - HealthMetricType Extension

private extension HealthMetricType {
    var unit: String {
        switch self {
        case .heartRate: return "BPM"
        case .steps: return "steps"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "mmHg"
        case .bloodGlucose: return "mg/dL"
        case .weight: return "kg"
        case .height: return "cm"
        case .bodyTemperature: return "°F"
        case .oxygenSaturation: return "%"
        case .respiratoryRate: return "breaths/min"
        case .sleepDuration: return "hours"
        case .caloriesBurned: return "kcal"
        case .waterIntake: return "liters"
        case .exerciseDuration: return "minutes"
        case .custom: return ""
        }
    }
    
    var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .steps: return "Steps"
        case .bloodPressureSystolic: return "Blood Pressure (Systolic)"
        case .bloodPressureDiastolic: return "Blood Pressure (Diastolic)"
        case .bloodGlucose: return "Blood Glucose"
        case .weight: return "Weight"
        case .height: return "Height"
        case .bodyTemperature: return "Body Temperature"
        case .oxygenSaturation: return "Oxygen Saturation"
        case .respiratoryRate: return "Respiratory Rate"
        case .sleepDuration: return "Sleep Duration"
        case .caloriesBurned: return "Calories Burned"
        case .waterIntake: return "Water Intake"
        case .exerciseDuration: return "Exercise Duration"
        case .custom(let name): return name
        }
    }
}