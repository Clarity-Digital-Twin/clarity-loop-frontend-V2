@testable import clarity_loop_frontend
import Foundation
import SwiftData

/// A testable version of HealthViewModel that works with mock repositories
/// This bypasses the final class restriction issue
@MainActor
final class TestableHealthViewModel: BaseViewModel {
    // MARK: - Properties
    
    private(set) var metricsState: ViewState<[HealthMetric]> = .idle
    private(set) var syncState: ViewState<SyncStatus> = .idle
    private(set) var selectedDateRange: DateRange = .week
    private(set) var selectedMetricType: HealthMetricType?
    
    // Using protocol instead of concrete class
    private let healthRepository: any HealthRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    
    // MARK: - Computed Properties
    
    var metrics: [HealthMetric] {
        metricsState.value ?? []
    }
    
    var isHealthKitAuthorized: Bool {
        healthKitService.isHealthDataAvailable()
    }
    
    var filteredMetrics: [HealthMetric] {
        guard let type = selectedMetricType else { return metrics }
        return metrics.filter { $0.type == type }
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        healthRepository: any HealthRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.healthRepository = healthRepository
        self.healthKitService = healthKitService
        super.init(modelContext: modelContext)
    }
    
    // MARK: - Public Methods (Same as HealthViewModel)
    
    func loadMetrics() async {
        metricsState = .loading
        
        do {
            let endDate = Date()
            let startDate = selectedDateRange.startDate(from: endDate)
            
            let metrics: [HealthMetric]
            if let type = selectedMetricType {
                metrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
            } else {
                var allMetrics: [HealthMetric] = []
                for type in HealthMetricType.allCases {
                    let typeMetrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
                    allMetrics.append(contentsOf: typeMetrics)
                }
                metrics = allMetrics
            }
            
            metricsState = metrics.isEmpty ? .empty : .loaded(metrics)
        } catch {
            metricsState = .error(error)
            handle(error: error)
        }
    }
    
    func selectDateRange(_ range: DateRange) {
        selectedDateRange = range
        Task {
            await loadMetrics()
        }
    }
    
    func selectMetricType(_ type: HealthMetricType?) {
        selectedMetricType = type
        Task {
            await loadMetrics()
        }
    }
    
    func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
            
            // Setup background delivery
            try await healthKitService.enableBackgroundDelivery()
            healthKitService.setupObserverQueries()
            print("✅ HealthKit background sync enabled from Health screen")
            
            await syncHealthData()
        } catch {
            handle(error: error)
        }
    }
    
    func syncHealthData() async {
        guard isHealthKitAuthorized else {
            await requestHealthKitAuthorization()
            return
        }
        
        syncState = .loading
        
        do {
            // Fetch latest data from HealthKit
            let endDate = Date()
            let dailyMetrics = try await healthKitService.fetchAllDailyMetrics(for: endDate)
            
            // Convert to HealthMetric models and save
            var healthMetrics: [HealthMetric] = []
            
            let date = dailyMetrics.date
            
            // Steps
            if dailyMetrics.stepCount > 0 {
                let stepMetric = HealthMetric(
                    timestamp: date,
                    value: Double(dailyMetrics.stepCount),
                    type: .steps,
                    unit: "steps"
                )
                stepMetric.source = "HealthKit"
                healthMetrics.append(stepMetric)
            }
            
            // Heart Rate
            if let heartRate = dailyMetrics.restingHeartRate {
                let heartMetric = HealthMetric(
                    timestamp: date,
                    value: heartRate,
                    type: .heartRate,
                    unit: "bpm"
                )
                heartMetric.source = "HealthKit"
                healthMetrics.append(heartMetric)
            }
            
            // Sleep
            if let sleepData = dailyMetrics.sleepData {
                let sleepMetric = HealthMetric(
                    timestamp: date,
                    value: sleepData.totalTimeAsleep / 3600, // Convert to hours
                    type: .sleepDuration,
                    unit: "hours"
                )
                sleepMetric.source = "HealthKit"
                sleepMetric.metadata = [
                    "efficiency": "\(sleepData.sleepEfficiency)",
                    "timeInBed": "\(sleepData.totalTimeInBed)",
                ]
                healthMetrics.append(sleepMetric)
            }
            
            // Save to repository
            try await healthRepository.createBatch(healthMetrics)
            
            // Sync with backend
            try await healthRepository.sync()
            
            syncState = .loaded(.synced)
            
            // Reload metrics to show new data
            await loadMetrics()
        } catch {
            syncState = .error(error)
            handle(error: error)
        }
    }
    
    func deleteMetric(_ metric: HealthMetric) async {
        do {
            try await healthRepository.delete(metric)
            await loadMetrics()
        } catch {
            handle(error: error)
        }
    }
}