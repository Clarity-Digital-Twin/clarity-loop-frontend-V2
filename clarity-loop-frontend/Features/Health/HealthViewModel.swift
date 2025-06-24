import Foundation
import HealthKit
import Observation
import SwiftData

@Observable
@MainActor
final class HealthViewModel: BaseViewModel {
    // MARK: - Properties

    private(set) var metricsState: ViewState<[HealthMetric]> = .idle
    private(set) var syncState: ViewState<SyncStatus> = .idle
    private(set) var selectedDateRange: DateRange = .week
    private(set) var selectedMetricType: HealthMetricType?

    // MARK: - Dependencies

    private let healthRepository: HealthRepository
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
        healthRepository: HealthRepository,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.healthRepository = healthRepository
        self.healthKitService = healthKitService
        super.init(modelContext: modelContext)
    }

    // MARK: - Public Methods

    func loadMetrics() async {
        metricsState = .loading

        do {
            let endDate = Date()
            let startDate = selectedDateRange.startDate(from: endDate)

            // If no type selected, fetch all types
            let metrics: [HealthMetric]
            if let type = selectedMetricType {
                metrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
            } else {
                // Fetch all types
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
            
            // 🔥 CRITICAL FIX: Setup background delivery immediately after authorization
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
            let _ = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!

            let dailyMetrics = try await healthKitService.fetchAllDailyMetrics(
                for: endDate
            )

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

    func exportMetrics() async -> URL? {
        do {
            let metrics = metrics

            // Convert to exportable format
            let exportData = metrics.map { metric in
                [
                    "id": metric.localID?.uuidString ?? UUID().uuidString,
                    "type": metric.type?.rawValue ?? "unknown",
                    "value": metric.value ?? 0.0,
                    "unit": metric.unit ?? "",
                    "timestamp": ISO8601DateFormatter().string(from: metric.timestamp ?? Date()),
                    "source": metric.source ?? "unknown",
                ] as [String: Any]
            }

            let data = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])

            let fileName = "health_metrics_\(Date().ISO8601Format()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try data.write(to: url)
            return url
        } catch {
            handle(error: error)
            return nil
        }
    }

    // MARK: - Mock Data

    #if DEBUG
        func loadMockData() {
            let mockMetrics = HealthMetric.generateMockData(days: 30)
            metricsState = .loaded(mockMetrics)
            syncState = .loaded(.synced)
        }
    #endif
}

// MARK: - Supporting Types

enum DateRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "Year"

    func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: endDate)!
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate)!
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate)!
        }
    }
}

// MARK: - HealthMetric Mock Data

#if DEBUG
    extension HealthMetric {
        static func generateMockData(days: Int) -> [HealthMetric] {
            var metrics: [HealthMetric] = []
            let calendar = Calendar.current
            let endDate = Date()

            for dayOffset in 0..<days {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) else { continue }

                // Steps
                let steps = HealthMetric(
                    timestamp: date,
                    value: Double.random(in: 5000...15000),
                    type: .steps,
                    unit: "steps"
                )
                steps.source = "Manual"
                metrics.append(steps)

                // Heart Rate
                let heartRate = HealthMetric(
                    timestamp: date,
                    value: Double.random(in: 60...80),
                    type: .heartRate,
                    unit: "bpm"
                )
                heartRate.source = "Manual"
                metrics.append(heartRate)

                // Sleep
                let sleep = HealthMetric(
                    timestamp: date,
                    value: Double.random(in: 6...9),
                    type: .sleepDuration,
                    unit: "hours"
                )
                sleep.source = "Manual"
                sleep.metadata = [
                    "efficiency": "\(Double.random(in: 0.7...0.95))",
                    "timeInBed": "\(Double.random(in: 7...10) * 3600)",
                ]
                metrics.append(sleep)
            }

            return metrics
        }
    }
#endif
