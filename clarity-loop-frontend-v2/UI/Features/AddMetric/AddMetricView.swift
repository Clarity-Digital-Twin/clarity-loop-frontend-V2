//
//  AddMetricView.swift
//  clarity-loop-frontend-v2
//
//  View for adding new health metrics
//

import SwiftUI
import ClarityDomain
import ClarityData
#if canImport(UIKit)
import UIKit
#endif

public struct AddMetricView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddMetricViewModel
    @FocusState private var isValueFieldFocused: Bool
    
    // MARK: - Initialization
    
    public init(viewModel: AddMetricViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            Form {
                metricTypeSection
                valueSection
                dateTimeSection
                notesSection
                
                if !viewModel.validationErrors.isEmpty {
                    validationErrorsSection
                }
                
                if let errorMessage = viewModel.errorMessage {
                    errorSection(message: errorMessage)
                }
            }
            .navigationTitle("Add Metric")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveMetric()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSubmitting || viewModel.value.isEmpty)
                }
            }
            .disabled(viewModel.isSubmitting)
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .onAppear {
            // Focus on value field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isValueFieldFocused = true
            }
        }
    }
    
    // MARK: - Sections
    
    private var metricTypeSection: some View {
        Section {
            Picker("Metric Type", selection: $viewModel.selectedMetricType) {
                ForEach(HealthMetricType.allCases, id: \.self) { type in
                    Label {
                        Text(type.displayName)
                    } icon: {
                        Image(systemName: type.icon)
                            .foregroundColor(type.color)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Type")
        }
    }
    
    private var valueSection: some View {
        Section {
            HStack {
                TextField(
                    viewModel.selectedMetricType.valuePlaceholder,
                    text: $viewModel.value
                )
                #if os(iOS)
                .keyboardType(viewModel.selectedMetricType.keyboardType)
                #endif
                .focused($isValueFieldFocused)
                .onChange(of: viewModel.value) { _, _ in
                    // Clear validation errors when user types
                    if !viewModel.validationErrors.isEmpty {
                        viewModel.validationErrors = []
                    }
                }
                
                Text(viewModel.selectedMetricType.defaultUnit)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Value")
        } footer: {
            if let hint = viewModel.selectedMetricType.inputHint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dateTimeSection: some View {
        Section {
            DatePicker(
                "Date & Time",
                selection: $viewModel.recordedAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
        } header: {
            Text("When")
        }
    }
    
    private var notesSection: some View {
        Section {
            TextField(
                "Optional notes",
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(3...6)
        } header: {
            Text("Notes")
        }
    }
    
    private var validationErrorsSection: some View {
        Section {
            ForEach(viewModel.validationErrors, id: \.self) { error in
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                }
            }
        }
        .listRowBackground(Color.red.opacity(0.1))
    }
    
    private func errorSection(message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
            }
        }
        .listRowBackground(Color.orange.opacity(0.1))
    }
    
    // MARK: - Actions
    
    private func saveMetric() async {
        // Hide keyboard
        isValueFieldFocused = false
        
        // Submit
        let success = await viewModel.submitMetric()
        
        if success {
            // Haptic feedback
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif
            
            // Dismiss
            dismiss()
        } else {
            // Error feedback
            #if os(iOS)
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            #endif
        }
    }
}

// MARK: - HealthMetricType UI Extensions

private extension HealthMetricType {
    var valuePlaceholder: String {
        switch self {
        case .heartRate:
            return "72"
        case .steps:
            return "10000"
        case .bloodPressureSystolic:
            return "120"
        case .bloodPressureDiastolic:
            return "80"
        case .bloodGlucose:
            return "95"
        case .bodyTemperature:
            return "98.6"
        case .oxygenSaturation:
            return "98"
        case .weight:
            return "150"
        case .height:
            return "68"
        case .sleepDuration:
            return "8"
        case .respiratoryRate:
            return "16"
        case .caloriesBurned:
            return "300"
        case .waterIntake:
            return "2.5"
        case .exerciseDuration:
            return "30"
        case .custom:
            return "100"
        }
    }
    
    #if os(iOS)
    var keyboardType: UIKeyboardType {
        switch self {
        case .bodyTemperature, .weight, .waterIntake:
            return .decimalPad
        default:
            return .numberPad
        }
    }
    #endif
    
    var inputHint: String? {
        switch self {
        case .bloodPressureSystolic:
            return "Systolic blood pressure"
        case .bloodPressureDiastolic:
            return "Diastolic blood pressure"
        case .bodyTemperature:
            return "In Fahrenheit"
        case .weight:
            return "In pounds"
        case .height:
            return "In inches"
        case .sleepDuration:
            return "Hours of sleep"
        case .exerciseDuration:
            return "Minutes of exercise"
        case .waterIntake:
            return "In liters"
        default:
            return nil
        }
    }
}

// MARK: - Previews

#if DEBUG
struct AddMetricView_Previews: PreviewProvider {
    static var previews: some View {
        AddMetricView(
            viewModel: AddMetricViewModel(
                repository: MockHealthMetricRepository(),
                apiClient: MockAPIClient.createForPreview(),
                userId: UUID()
            )
        )
    }
}

private final class MockHealthMetricRepository: HealthMetricRepositoryProtocol {
    func create(_ metric: HealthMetric) async throws -> HealthMetric { metric }
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] { metrics }
    func findById(_ id: UUID) async throws -> HealthMetric? { nil }
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] { [] }
    func findByUserIdAndDateRange(userId: UUID, startDate: Date, endDate: Date) async throws -> [HealthMetric] { [] }
    func findByUserIdAndType(userId: UUID, type: HealthMetricType) async throws -> [HealthMetric] { [] }
    func update(_ metric: HealthMetric) async throws -> HealthMetric { metric }
    func delete(_ id: UUID) async throws {}
    func deleteAllForUser(_ userId: UUID) async throws {}
    func getLatestByType(userId: UUID, type: HealthMetricType) async throws -> HealthMetric? { nil }
}

private final class MockAPIClient {
    init() {}
}

extension MockAPIClient {
    static func createForPreview() -> APIClient {
        APIClient(networkService: MockNetworkService())
    }
}

private final class MockNetworkService: NetworkServiceProtocol {
    func request<T>(_ endpoint: Endpoint, type: T.Type) async throws -> T where T: Decodable {
        // Return mock health data response for preview
        if T.self == HealthDataResponse.self {
            let response = HealthDataResponse(
                processing_id: "mock-processing-id",
                status: "success",
                message: "Mock upload successful"
            )
            return response as! T
        }
        fatalError("Not implemented for preview")
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        fatalError("Not implemented for preview")
    }
    
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        fatalError("Not implemented for preview")
    }
    
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        fatalError("Not implemented for preview")
    }
}

// Mock response type
private struct HealthDataResponse: Codable {
    let processing_id: String
    let status: String
    let message: String
}
#endif
