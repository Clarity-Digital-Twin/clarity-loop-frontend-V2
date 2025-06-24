import Combine
import Foundation
import HealthKit

/// Manages automatic syncing between HealthKit and backend
@MainActor
final class HealthKitSyncService: ObservableObject {
    // MARK: - Properties

    static var shared: HealthKitSyncService?

    @Published private(set) var syncStatus: HealthKitSyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncProgress = 0.0
    @Published private(set) var syncErrors: [SyncError] = []

    private let healthStore = HKHealthStore()
    private let healthKitService: HealthKitServiceProtocol
    private let healthRepository: HealthRepository
    private let apiClient: APIClientProtocol
    private let backgroundTaskManager: BackgroundTaskManager

    private var syncTimer: Timer?
    private var activeQueries: Set<HKQuery> = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    private let syncInterval: TimeInterval = 3600 // 1 hour
    private let batchSize = 100
    private let maxRetries = 3

    // MARK: - Initialization

    static func configure(
        healthKitService: HealthKitServiceProtocol,
        healthRepository: HealthRepository,
        apiClient: APIClientProtocol,
        backgroundTaskManager: BackgroundTaskManager
    ) {
        shared = HealthKitSyncService(
            healthKitService: healthKitService,
            healthRepository: healthRepository,
            apiClient: apiClient,
            backgroundTaskManager: backgroundTaskManager
        )
    }

    private init(
        healthKitService: HealthKitServiceProtocol,
        healthRepository: HealthRepository,
        apiClient: APIClientProtocol,
        backgroundTaskManager: BackgroundTaskManager
    ) {
        self.healthKitService = healthKitService
        self.healthRepository = healthRepository
        self.apiClient = apiClient
        self.backgroundTaskManager = backgroundTaskManager

        setupObservers()
        registerBackgroundTasks()
    }

    // MARK: - Public Methods

    /// Start automatic syncing
    func startAutoSync() {
        // Check if HealthKit is available
        guard healthKitService.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }

        // Initial sync
        Task {
            await performFullSync()
        }

        // Setup periodic sync
        setupPeriodicSync()

        // Setup real-time monitoring
        setupHealthKitObservers()
    }

    /// Stop automatic syncing
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil

        // Stop all active queries
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
    }

    /// Manually trigger a full sync
    func performFullSync() async {
        syncStatus = .syncing
        syncProgress = 0.0
        syncErrors.removeAll()

        do {
            // Sync each data type
            try await syncSteps()
            syncProgress = 0.2

            try await syncHeartRate()
            syncProgress = 0.4

            try await syncSleep()
            syncProgress = 0.6

            try await syncWorkouts()
            syncProgress = 0.8

            try await syncNutrition()
            syncProgress = 1.0

            // Update last sync date
            lastSyncDate = Date()
            syncStatus = .synced

            // Save sync metadata
            UserDefaults.standard.set(lastSyncDate, forKey: "lastHealthKitSyncDate")

        } catch {
            syncStatus = .failed
            syncErrors.append(SyncError(
                timestamp: Date(),
                dataType: "General",
                error: error
            ))
        }
    }

    /// Sync specific date range
    func syncDateRange(from startDate: Date, to endDate: Date) async {
        syncStatus = .syncing

        do {
            // Create predicate for date range
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            // Sync each type for the date range
            try await syncSteps(predicate: predicate)
            try await syncHeartRate(predicate: predicate)
            try await syncSleep(predicate: predicate)

            syncStatus = .synced
        } catch {
            syncStatus = .failed
            syncErrors.append(SyncError(
                timestamp: Date(),
                dataType: "DateRange",
                error: error
            ))
        }
    }

    // MARK: - Private Sync Methods

    private func syncSteps(predicate: NSPredicate? = nil) async throws {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let samples = try await fetchSamples(type: stepType, predicate: predicate)

        var metrics: [HealthMetric] = []

        for sample in samples {
            let quantity = sample as! HKQuantitySample
            let value = quantity.quantity.doubleValue(for: .count())

            let metric = HealthMetric(
                timestamp: quantity.startDate,
                value: value,
                type: .steps,
                unit: "steps"
            )
            metric.source = "HealthKit"
            metric.metadata = [
                "device": quantity.device?.name ?? "Unknown",
                "uuid": quantity.uuid.uuidString,
            ]

            metrics.append(metric)
        }

        // Batch save and upload
        try await processBatch(metrics)
    }

    private func syncHeartRate(predicate: NSPredicate? = nil) async throws {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let samples = try await fetchSamples(type: heartRateType, predicate: predicate)

        var metrics: [HealthMetric] = []

        for sample in samples {
            let quantity = sample as! HKQuantitySample
            let value = quantity.quantity.doubleValue(for: HKUnit(from: "count/min"))

            let metric = HealthMetric(
                timestamp: quantity.startDate,
                value: value,
                type: .heartRate,
                unit: "bpm"
            )
            metric.source = "HealthKit"
            metric.metadata = [
                "motionContext": getMotionContext(for: quantity),
            ]

            metrics.append(metric)
        }

        try await processBatch(metrics)
    }

    private func syncSleep(predicate: NSPredicate? = nil) async throws {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let samples = try await fetchSamples(type: sleepType, predicate: predicate)

        // Group sleep samples by day
        let calendar = Calendar.current
        var dailySleep: [Date: [HKCategorySample]] = [:]

        for sample in samples {
            let categorySample = sample as! HKCategorySample
            let startOfDay = calendar.startOfDay(for: categorySample.startDate)

            if dailySleep[startOfDay] == nil {
                dailySleep[startOfDay] = []
            }
            dailySleep[startOfDay]?.append(categorySample)
        }

        // Create sleep metrics
        var metrics: [HealthMetric] = []

        for (date, samples) in dailySleep {
            let totalSleep = calculateTotalSleep(from: samples)

            let metric = HealthMetric(
                timestamp: date,
                value: totalSleep / 3600, // Convert to hours
                type: .sleepDuration,
                unit: "hours"
            )
            metric.source = "HealthKit"
            metric.metadata = [
                "stages": analyzeSleepStages(from: samples),
            ]

            metrics.append(metric)
        }

        try await processBatch(metrics)
    }

    private func syncWorkouts(predicate: NSPredicate? = nil) async throws {
        let workoutType = HKWorkoutType.workoutType()
        let samples = try await fetchSamples(type: workoutType, predicate: predicate)

        var metrics: [HealthMetric] = []

        for sample in samples {
            let workout = sample as! HKWorkout

            // Active energy - use statistics for iOS 18+
            if #available(iOS 18.0, *) {
                if
                    let energyStats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
                    let energy = energyStats.sumQuantity() {
                    let metric = HealthMetric(
                        timestamp: workout.startDate,
                        value: energy.doubleValue(for: .kilocalorie()),
                        type: .activeEnergy,
                        unit: "kcal"
                    )
                    metric.source = "HealthKit"
                    metric.metadata = [
                        "workoutType": workout.workoutActivityType.name,
                        "duration": "\(workout.duration)",
                    ]

                    metrics.append(metric)
                }
            } else {
                // Fallback for older iOS versions
                if let energy = workout.totalEnergyBurned {
                    let metric = HealthMetric(
                        timestamp: workout.startDate,
                        value: energy.doubleValue(for: .kilocalorie()),
                        type: .activeEnergy,
                        unit: "kcal"
                    )
                    metric.source = "HealthKit"
                    metric.metadata = [
                        "workoutType": workout.workoutActivityType.name,
                        "duration": "\(workout.duration)",
                    ]

                    metrics.append(metric)
                }
            }
        }

        try await processBatch(metrics)
    }

    private func syncNutrition() async throws {
        // TODO: Implement nutrition sync
    }

    // MARK: - HealthKit Queries

    private func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate? = nil
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let finalPredicate = predicate ?? HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-7 * 24 * 3600), // Last 7 days
                end: Date(),
                options: .strictStartDate
            )

            let query = HKSampleQuery(
                sampleType: type,
                predicate: finalPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }

            healthStore.execute(query)
        }
    }

    private func setupHealthKitObservers() {
        // Steps observer
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepsQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
                if error == nil {
                    Task { @MainActor in
                        try? await self?.syncSteps()
                    }
                }
            }
            healthStore.execute(stepsQuery)
            activeQueries.insert(stepsQuery)
        }

        // Heart rate observer
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
                if error == nil {
                    Task { @MainActor in
                        try? await self?.syncHeartRate()
                    }
                }
            }
            healthStore.execute(heartRateQuery)
            activeQueries.insert(heartRateQuery)
        }
    }

    // MARK: - Batch Processing

    private func processBatch(_ metrics: [HealthMetric]) async throws {
        guard !metrics.isEmpty else { return }

        // Save locally first
        try await healthRepository.createBatch(metrics)

        // Upload in chunks
        let chunks = metrics.chunked(into: batchSize)

        for chunk in chunks {
            do {
                try await healthRepository.batchUpload(metrics: chunk)
            } catch {
                // Mark failed uploads for retry
                for metric in chunk {
                    metric.syncStatus = .failed
                    metric.syncError = error.localizedDescription
                }
                throw error
            }
        }
    }

    // MARK: - Helper Methods

    private func getMotionContext(for sample: HKQuantitySample) -> String {
        // Check metadata for motion context
        if
            let metadata = sample.metadata,
            let context = metadata[HKMetadataKeyHeartRateMotionContext] as? NSNumber {
            switch context.intValue {
            case 1: return "sedentary"
            case 2: return "active"
            default: return "unknown"
            }
        }
        return "unknown"
    }

    private func calculateTotalSleep(from samples: [HKCategorySample]) -> TimeInterval {
        var totalSleep: TimeInterval = 0

        for sample in samples {
            if
                sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
            }
        }

        return totalSleep
    }

    private func analyzeSleepStages(from samples: [HKCategorySample]) -> String {
        // Simplified sleep stage analysis
        var stages: [String: TimeInterval] = [:]

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stages["rem", default: 0] += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stages["deep", default: 0] += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stages["light", default: 0] += duration
            default:
                break
            }
        }

        return stages.map { "\($0.key):\($0.value)" }.joined(separator: ",")
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe authorization changes
        NotificationCenter.default.publisher(for: .healthKitAuthorizationStatusChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAuthorizationChange()
                }
            }
            .store(in: &cancellables)
    }

    private func setupPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performFullSync()
            }
        }
    }

    private func registerBackgroundTasks() {
        // Background sync is handled by BackgroundTaskManager
    }

    private func handleAuthorizationChange() async {
        if healthKitService.isHealthDataAvailable() {
            await performFullSync()
        } else {
            stopAutoSync()
        }
    }
}

// MARK: - Supporting Types

enum HealthKitSyncStatus {
    case idle
    case syncing
    case synced
    case failed
}

struct SyncError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let dataType: String
    let error: Error
}

// MARK: - Extensions

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        default: "Other"
        }
    }
}

// Array.chunked is already defined in EnhancedOfflineQueueManager

extension Notification.Name {
    static let healthKitAuthorizationStatusChanged = Notification.Name("healthKitAuthorizationStatusChanged")
}
