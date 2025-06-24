@testable import clarity_loop_frontend
import Foundation
import HealthKit

class MockHealthKitService: HealthKitServiceProtocol {
    var shouldSucceed = true
    var mockDailyMetrics: DailyHealthMetrics?
    var mockStepCount = 5000.0
    var mockDailySteps = 5000.0
    var mockRestingHeartRate: Double? = 72.0
    var mockSleepData: SleepData? = SleepData(
        totalTimeInBed: 28800, // 8 hours
        totalTimeAsleep: 25200, // 7 hours
        sleepEfficiency: 0.875 // 87.5%
    )
    var shouldFailFetch = false
    var fetchError: Error?

    func isHealthDataAvailable() -> Bool {
        shouldSucceed
    }

    func requestAuthorization() async throws {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
    }

    func fetchDailySteps(for date: Date) async throws -> Double {
        if shouldFailFetch {
            throw fetchError ?? HealthKitError.dataTypeNotAvailable
        }
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
        return mockDailySteps
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
        return mockRestingHeartRate
    }

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData? {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
        return mockSleepData
    }

    func fetchAllDailyMetrics(for date: Date) async throws -> DailyHealthMetrics {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }

        if let mockMetrics = mockDailyMetrics {
            return mockMetrics
        }

        return DailyHealthMetrics(
            date: date,
            stepCount: Int(mockStepCount),
            restingHeartRate: mockRestingHeartRate,
            sleepData: mockSleepData
        )
    }

    func uploadHealthKitData(_ uploadRequest: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        if !shouldSucceed {
            throw APIError.serverError(statusCode: 500, message: "Mock upload failed")
        }

        return HealthKitUploadResponseDTO(
            success: true,
            uploadId: "mock-upload-id",
            processedSamples: uploadRequest.samples.count,
            skippedSamples: 0,
            errors: nil,
            message: "Mock upload successful"
        )
    }

    func enableBackgroundDelivery() async throws {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
    }

    func disableBackgroundDelivery() async throws {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
    }

    func setupObserverQueries() {
        // Mock implementation - no-op
    }
    
    func fetchHealthDataForUpload(from startDate: Date, to endDate: Date, userId: String) async throws -> HealthKitUploadRequestDTO {
        if !shouldSucceed {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        var samples: [HealthKitSampleDTO] = []
        
        // Add some mock step data
        samples.append(HealthKitSampleDTO(
            sampleType: "stepCount",
            value: mockStepCount,
            categoryValue: nil,
            unit: "count",
            startDate: startDate,
            endDate: endDate,
            metadata: nil,
            sourceRevision: nil
        ))
        
        // Add mock heart rate data if available
        if let heartRate = mockRestingHeartRate {
            samples.append(HealthKitSampleDTO(
                sampleType: "restingHeartRate",
                value: heartRate,
                categoryValue: nil,
                unit: "count/min",
                startDate: startDate,
                endDate: endDate,
                metadata: nil,
                sourceRevision: nil
            ))
        }
        
        return HealthKitUploadRequestDTO(
            userId: userId,
            samples: samples,
            deviceInfo: DeviceInfoDTO(
                deviceModel: "iPhone",
                systemName: "iOS",
                systemVersion: "17.0",
                appVersion: "1.0",
                timeZone: TimeZone.current.identifier
            ),
            timestamp: Date()
        )
    }
}
