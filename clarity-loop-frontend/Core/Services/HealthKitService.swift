import Foundation
import HealthKit
import UIKit

class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()
    private let apiClient: APIClientProtocol
    private var offlineQueueManager: OfflineQueueManagerProtocol?

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func setOfflineQueueManager(_ manager: OfflineQueueManagerProtocol) {
        offlineQueueManager = manager
    }

    /// The set of `HKObjectType`s the app will request permission to read.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
        ]

        for identifier in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }

        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        return types
    }

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchDailySteps(for date: Date) async throws -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.endOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        _ = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, _, _ in
            // This part is tricky to wrap in an async call, let's do it properly.
        }

        // The above is just a placeholder, here's the real implementation using a continuation.
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sum = result?.sumQuantity() else {
                    // If there's no data, return 0 steps.
                    continuation.resume(returning: 0.0)
                    return
                }

                let steps = sum.doubleValue(for: .count())
                continuation.resume(returning: steps)
            }

            healthStore.execute(query)
        }
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.endOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: heartRate)
            }

            healthStore.execute(query)
        }
    }

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        // Predicate for the previous night (e.g., from noon yesterday to noon today)
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: date)
        guard let startDate = calendar.date(byAdding: .hour, value: -12, to: endDate) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let totalTimeInBed = samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let totalTimeAsleep = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let sleepEfficiency = totalTimeInBed > 0 ? (totalTimeAsleep / totalTimeInBed) : 0

                let sleepData = SleepData(
                    totalTimeInBed: totalTimeInBed,
                    totalTimeAsleep: totalTimeAsleep,
                    sleepEfficiency: sleepEfficiency
                )

                continuation.resume(returning: sleepData)
            }

            healthStore.execute(query)
        }
    }

    func fetchAllDailyMetrics(for date: Date) async throws -> DailyHealthMetrics {
        async let steps = fetchDailySteps(for: date)
        async let heartRate = fetchRestingHeartRate(for: date)
        async let sleep = fetchSleepAnalysis(for: date)

        let (stepCount, restingHeartRate, sleepData) = try await (steps, heartRate, sleep)

        return DailyHealthMetrics(
            date: date,
            stepCount: Int(stepCount),
            restingHeartRate: restingHeartRate,
            sleepData: sleepData
        )
    }
    
    // MARK: - Health Data Sync
    
    /// Fetch all health data for upload in the correct format
    func fetchHealthDataForUpload(from startDate: Date, to endDate: Date, userId: String) async throws -> HealthKitUploadRequestDTO {
        var samples: [HealthKitSampleDTO] = []
        
        // Fetch step count data
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepSamples = try await fetchSamples(of: stepType, from: startDate, to: endDate)
            samples.append(contentsOf: stepSamples.map { sample in
                HealthKitSampleDTO(
                    sampleType: "stepCount",
                    value: sample.quantity.doubleValue(for: .count()),
                    categoryValue: nil,
                    unit: "count",
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    metadata: nil,
                    sourceRevision: convertSourceRevision(sample.sourceRevision)
                )
            })
        }
        
        // Fetch heart rate data
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let heartRateSamples = try await fetchSamples(of: heartRateType, from: startDate, to: endDate)
            samples.append(contentsOf: heartRateSamples.map { sample in
                HealthKitSampleDTO(
                    sampleType: "heartRate",
                    value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    categoryValue: nil,
                    unit: "count/min",
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    metadata: nil,
                    sourceRevision: convertSourceRevision(sample.sourceRevision)
                )
            })
        }
        
        // Fetch resting heart rate data
        if let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let restingHRSamples = try await fetchSamples(of: restingHeartRateType, from: startDate, to: endDate)
            samples.append(contentsOf: restingHRSamples.map { sample in
                HealthKitSampleDTO(
                    sampleType: "restingHeartRate",
                    value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    categoryValue: nil,
                    unit: "count/min",
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    metadata: nil,
                    sourceRevision: convertSourceRevision(sample.sourceRevision)
                )
            })
        }
        
        // Fetch sleep data
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let sleepSamples = try await fetchCategorySamples(of: sleepType, from: startDate, to: endDate)
            samples.append(contentsOf: sleepSamples.map { sample in
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60 // Convert to minutes
                return HealthKitSampleDTO(
                    sampleType: "sleepAnalysis",
                    value: duration,
                    categoryValue: sample.value,
                    unit: "min",
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    metadata: ["sleep_stage": AnyCodable(sleepStageString(from: sample.value))],
                    sourceRevision: convertSourceRevision(sample.sourceRevision)
                )
            })
        }
        
        // Get device info
        let deviceInfo = DeviceInfoDTO(
            deviceModel: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            timeZone: TimeZone.current.identifier
        )
        
        return HealthKitUploadRequestDTO(
            userId: userId,
            samples: samples,
            deviceInfo: deviceInfo,
            timestamp: Date()
        )
    }
    
    private func fetchSamples(of type: HKQuantityType, from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchCategorySamples(of type: HKCategoryType, from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func convertSourceRevision(_ sourceRevision: HKSourceRevision) -> SourceRevisionDTO {
        SourceRevisionDTO(
            source: SourceDTO(
                name: sourceRevision.source.name,
                bundleIdentifier: sourceRevision.source.bundleIdentifier
            ),
            version: sourceRevision.version,
            productType: sourceRevision.productType,
            operatingSystemVersion: "\(sourceRevision.operatingSystemVersion.majorVersion).\(sourceRevision.operatingSystemVersion.minorVersion).\(sourceRevision.operatingSystemVersion.patchVersion)"
        )
    }
    
    private func sleepStageString(from value: Int) -> String {
        guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: value) else {
            return "unknown"
        }
        
        switch sleepValue {
        case .inBed:
            return "in_bed"
        case .asleepUnspecified:
            return "asleep_unspecified"
        case .awake:
            return "awake"
        case .asleepCore:
            return "asleep_core"
        case .asleepDeep:
            return "asleep_deep"
        case .asleepREM:
            return "asleep_rem"
        @unknown default:
            return "unknown"
        }
    }

    func uploadHealthKitData(_ uploadRequest: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        do {
            return try await apiClient.uploadHealthKitData(requestDTO: uploadRequest)
        } catch {
            // If the upload fails due to network issues, queue it for later
            if
                let apiError = error as? APIError,
                case .networkError = apiError,
                let queueManager = offlineQueueManager {
                let queuedUpload = try uploadRequest.toQueuedUpload()
                try await queueManager.enqueue(queuedUpload)

                // Return a placeholder response indicating the upload was queued
                return HealthKitUploadResponseDTO(
                    success: true,
                    uploadId: queuedUpload.id.uuidString,
                    processedSamples: uploadRequest.samples.count,
                    skippedSamples: 0,
                    errors: nil,
                    message: "Upload queued for offline processing"
                )
            }
            throw error
        }
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() async throws {
        for dataType in readTypes {
            guard let quantityType = dataType as? HKQuantityType else { continue }

            return try await withCheckedThrowingContinuation { continuation in
                healthStore.enableBackgroundDelivery(for: quantityType, frequency: .hourly) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func disableBackgroundDelivery() async throws {
        for dataType in readTypes {
            guard let quantityType = dataType as? HKQuantityType else { continue }

            return try await withCheckedThrowingContinuation { continuation in
                healthStore.disableBackgroundDelivery(for: quantityType) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func setupObserverQueries() {
        for dataType in readTypes {
            // Only create observer queries for sample types (not category types)
            guard let sampleType = dataType as? HKSampleType else { continue }
            let query = HKObserverQuery(
                sampleType: sampleType,
                predicate: nil
            ) { [weak self] _, completionHandler, error in
                if let error {
                    print("Observer query error: \(error)")
                    return
                }

                // Schedule background task for data sync
                self?.scheduleBackgroundSync(for: sampleType)

                // Call completion handler to indicate we've handled the update
                completionHandler()
            }

            healthStore.execute(query)
        }
    }

    private func scheduleBackgroundSync(for dataType: HKObjectType) {
        // Post notification that can be observed by the app
        NotificationCenter.default.post(
            name: .healthKitDataUpdated,
            object: nil,
            userInfo: ["dataType": dataType.identifier]
        )
    }
}

enum HealthKitError: Error {
    case dataTypeNotAvailable
}

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        guard let endOfDay = self.date(byAdding: .init(day: 1, second: -1), to: start) else {
            // This fallback is unlikely to be hit with valid dates, but it's safer than force unwrapping.
            return start.addingTimeInterval(86399) // 24 hours minus 1 second
        }
        return endOfDay
    }
}

extension Notification.Name {
    static let healthKitDataUpdated = Notification.Name("healthKitDataUpdated")
    static let healthDataSynced = Notification.Name("healthDataSynced")
}
