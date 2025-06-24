@testable import clarity_loop_frontend
import XCTest

final class HealthKitServiceTests: XCTestCase {
    var mockHealthKitService: MockHealthKitService!
    var mockAPIClient: MockAPIClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPIClient = MockAPIClient()
        mockHealthKitService = MockHealthKitService()
    }

    override func tearDownWithError() throws {
        mockHealthKitService = nil
        mockAPIClient = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testRequestAuthorization_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        
        // When/Then - should not throw
        try await mockHealthKitService.requestAuthorization()
    }

    func testRequestAuthorization_Failure() async {
        // Given
        mockHealthKitService.shouldSucceed = false
        
        // When/Then
        do {
            try await mockHealthKitService.requestAuthorization()
            XCTFail("Expected authorization to fail")
        } catch {
            XCTAssertTrue(error is HealthKitError)
        }
    }

    func testFetchDailySteps_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockStepCount = 7500.0
        let testDate = Date()
        
        // When
        let steps = try await mockHealthKitService.fetchDailySteps(for: testDate)
        
        // Then
        XCTAssertEqual(steps, 7500.0, accuracy: 0.1)
    }

    func testFetchDailySteps_Error() async {
        // Given
        mockHealthKitService.shouldSucceed = false
        
        // When/Then
        do {
            _ = try await mockHealthKitService.fetchDailySteps(for: Date())
            XCTFail("Expected fetch to fail")
        } catch {
            XCTAssertTrue(error is HealthKitError)
        }
    }

    func testFetchRestingHeartRate_WithData() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockRestingHeartRate = 65.0
        
        // When
        let heartRate = try await mockHealthKitService.fetchRestingHeartRate(for: Date())
        
        // Then
        XCTAssertEqual(heartRate, 65.0)
    }

    func testFetchRestingHeartRate_NoData() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockRestingHeartRate = nil
        
        // When
        let heartRate = try await mockHealthKitService.fetchRestingHeartRate(for: Date())
        
        // Then
        XCTAssertNil(heartRate)
    }

    func testFetchSleepAnalysis_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        let expectedSleepData = SleepData(
            totalTimeInBed: 32400, // 9 hours
            totalTimeAsleep: 28800, // 8 hours
            sleepEfficiency: 0.889
        )
        mockHealthKitService.mockSleepData = expectedSleepData
        
        // When
        let sleepData = try await mockHealthKitService.fetchSleepAnalysis(for: Date())
        
        // Then
        XCTAssertNotNil(sleepData)
        XCTAssertEqual(sleepData?.totalTimeInBed, 32400)
        XCTAssertEqual(sleepData?.totalTimeAsleep, 28800)
        XCTAssertEqual(sleepData?.sleepEfficiency ?? 0, 0.889, accuracy: 0.001)
    }

    func testFetchAllDailyMetrics_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockStepCount = 10000
        mockHealthKitService.mockRestingHeartRate = 60
        mockHealthKitService.mockSleepData = SleepData(
            totalTimeInBed: 28800,
            totalTimeAsleep: 25200,
            sleepEfficiency: 0.875
        )
        let testDate = Date()
        
        // When
        let metrics = try await mockHealthKitService.fetchAllDailyMetrics(for: testDate)
        
        // Then
        XCTAssertEqual(metrics.stepCount, 10000)
        XCTAssertEqual(metrics.restingHeartRate, 60.0)
        XCTAssertNotNil(metrics.sleepData)
        XCTAssertEqual(metrics.sleepData?.sleepEfficiency ?? 0, 0.875, accuracy: 0.001)
    }

    func testFetchHealthDataForUpload_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        let startDate = Date().addingTimeInterval(-86400) // 1 day ago
        let endDate = Date()
        let userId = "test-user-123"
        
        // When
        let uploadData = try await mockHealthKitService.fetchHealthDataForUpload(
            from: startDate,
            to: endDate,
            userId: userId
        )
        
        // Then
        XCTAssertEqual(uploadData.userId, userId)
        XCTAssertFalse(uploadData.samples.isEmpty)
        XCTAssertNotNil(uploadData.deviceInfo)
        XCTAssertNotNil(uploadData.timestamp)
        
        // Verify at least step count sample exists
        let stepSample = uploadData.samples.first { $0.sampleType == "stepCount" }
        XCTAssertNotNil(stepSample)
        XCTAssertEqual(stepSample?.value, mockHealthKitService.mockStepCount)
    }

    func testUploadHealthKitData_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        mockAPIClient.shouldSucceed = true
        
        let uploadRequest = HealthKitUploadRequestDTO(
            userId: "test-user",
            samples: [
                HealthKitSampleDTO(
                    sampleType: "stepCount",
                    value: 5000,
                    categoryValue: nil,
                    unit: "count",
                    startDate: Date(),
                    endDate: Date(),
                    metadata: nil,
                    sourceRevision: nil
                )
            ],
            deviceInfo: DeviceInfoDTO(
                deviceModel: "iPhone",
                systemName: "iOS",
                systemVersion: "17.0",
                appVersion: "1.0",
                timeZone: "UTC"
            ),
            timestamp: Date()
        )
        
        // When
        let response = try await mockHealthKitService.uploadHealthKitData(uploadRequest)
        
        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.processedSamples, 1)
        XCTAssertEqual(response.skippedSamples, 0)
    }

    func testUploadHealthKitData_NetworkError_QueuesOffline() async throws {
        // Given
        mockHealthKitService.shouldSucceed = false
        
        let uploadRequest = HealthKitUploadRequestDTO(
            userId: "test-user",
            samples: [],
            deviceInfo: DeviceInfoDTO(
                deviceModel: "iPhone",
                systemName: "iOS", 
                systemVersion: "17.0",
                appVersion: "1.0",
                timeZone: "UTC"
            ),
            timestamp: Date()
        )
        
        // When/Then
        do {
            _ = try await mockHealthKitService.uploadHealthKitData(uploadRequest)
            XCTFail("Expected upload to fail")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testHealthDataAvailable() {
        // Given
        mockHealthKitService.shouldSucceed = true
        
        // When
        let isAvailable = mockHealthKitService.isHealthDataAvailable()
        
        // Then
        XCTAssertTrue(isAvailable)
    }

    func testEnableBackgroundDelivery_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        
        // When/Then - should not throw
        try await mockHealthKitService.enableBackgroundDelivery()
    }

    func testDisableBackgroundDelivery_Success() async throws {
        // Given
        mockHealthKitService.shouldSucceed = true
        
        // When/Then - should not throw
        try await mockHealthKitService.disableBackgroundDelivery()
    }

    func testSetupObserverQueries() {
        // Given
        mockHealthKitService.shouldSucceed = true
        
        // When/Then - should not crash
        mockHealthKitService.setupObserverQueries()
    }
}
