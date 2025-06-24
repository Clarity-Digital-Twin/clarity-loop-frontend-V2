import Foundation

final class FetchDailyHealthSummaryUseCase {
    private let healthDataRepository: HealthDataRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol

    init(
        healthDataRepository: HealthDataRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.healthDataRepository = healthDataRepository
        self.healthKitService = healthKitService
    }

    func execute(for date: Date = Date()) async throws -> DailyHealthSummary {
        // Fetch latest metrics from local HealthKit data
        let localMetrics = try await healthKitService.fetchAllDailyMetrics(for: date)

        // Fetch synchronized data from remote API
        let remoteData = try await healthDataRepository.getHealthData(page: 1, limit: 10)

        // Combine and process the data
        return DailyHealthSummary(
            date: date,
            stepCount: Int(localMetrics.stepCount),
            restingHeartRate: localMetrics.restingHeartRate,
            sleepData: localMetrics.sleepData,
            remoteMetrics: remoteData.data,
            lastUpdated: Date()
        )
    }
}

struct DailyHealthSummary {
    let date: Date
    let stepCount: Int
    let restingHeartRate: Double?
    let sleepData: SleepData?
    let remoteMetrics: [HealthMetricDTO]
    let lastUpdated: Date

    var hasCompleteData: Bool {
        stepCount > 0 || restingHeartRate != nil || sleepData != nil
    }

    var sleepEfficiency: Double? {
        sleepData?.sleepEfficiency
    }

    var totalSleepHours: Double? {
        guard let sleepData else { return nil }
        return sleepData.totalTimeAsleep / 3600.0 // Convert from seconds to hours
    }
}
