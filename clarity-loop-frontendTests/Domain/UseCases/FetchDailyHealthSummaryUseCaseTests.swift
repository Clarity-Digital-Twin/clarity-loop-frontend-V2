@testable import clarity_loop_frontend
import XCTest

final class FetchDailyHealthSummaryUseCaseTests: XCTestCase {
    var fetchDailyHealthSummaryUseCase: FetchDailyHealthSummaryUseCase!
    var mockHealthKitService: MockHealthKitService!
    var mockAPIClient: MockAPIClient!
    var mockHealthDataRepository: RemoteHealthDataRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize mocks
        mockHealthKitService = MockHealthKitService()
        mockAPIClient = MockAPIClient()
        mockHealthDataRepository = RemoteHealthDataRepository(apiClient: mockAPIClient)
        
        // Initialize use case
        fetchDailyHealthSummaryUseCase = FetchDailyHealthSummaryUseCase(
            healthDataRepository: mockHealthDataRepository,
            healthKitService: mockHealthKitService
        )
    }

    override func tearDownWithError() throws {
        fetchDailyHealthSummaryUseCase = nil
        mockHealthDataRepository = nil
        mockHealthKitService = nil
        mockAPIClient = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testExecute_Success() async throws {
        // Given: Mock services return valid data
        let testDate = Date()
        
        // Configure HealthKit mock
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 10000,
            restingHeartRate: 65,
            activeCalories: 350,
            exerciseMinutes: 45,
            standHours: 10,
            sleepData: SleepData(
                totalTimeInBed: 28800, // 8 hours
                totalTimeAsleep: 25200, // 7 hours
                sleepEfficiency: 0.875
            )
        )
        
        // Configure API mock to return health data
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthDataHandler = { page, limit in
            XCTAssertEqual(page, 1, "Should request first page")
            XCTAssertEqual(limit, 10, "Should request 10 items")
            
            return PaginatedMetricsResponseDTO(
                metrics: [
                    HealthMetricDTO(
                        id: UUID(),
                        userId: "test-user",
                        metricType: "steps",
                        timestamp: testDate,
                        metadata: nil,
                        activityData: ActivityDataDTO(
                            steps: 10000,
                            distance: 8.5,
                            floorsClimbed: 15,
                            activeCalories: 350,
                            exerciseMinutes: 45
                        ),
                        biometricData: nil,
                        sleepData: nil,
                        nutritionData: nil,
                        source: "healthkit",
                        deviceInfo: nil
                    ),
                    HealthMetricDTO(
                        id: UUID(),
                        userId: "test-user",
                        metricType: "heart_rate",
                        timestamp: testDate,
                        metadata: nil,
                        activityData: nil,
                        biometricData: BiometricDataDTO(
                            heartRate: 65,
                            heartRateVariability: 45,
                            bloodPressureSystolic: 120,
                            bloodPressureDiastolic: 80,
                            respiratoryRate: 16,
                            oxygenSaturation: 98,
                            bodyTemperature: 36.6
                        ),
                        sleepData: nil,
                        nutritionData: nil,
                        source: "healthkit",
                        deviceInfo: nil
                    )
                ],
                pagination: PaginationInfoDTO(
                    page: 1,
                    limit: 10,
                    totalPages: 1,
                    totalCount: 2,
                    hasNextPage: false,
                    hasPreviousPage: false
                ),
                metadata: nil
            )
        }

        // When: Execute fetch daily health summary
        let summary = try await fetchDailyHealthSummaryUseCase.execute(for: testDate)

        // Then: Verify summary contains combined data
        XCTAssertNotNil(summary, "Should return a summary")
        XCTAssertEqual(summary.date.day, testDate.day, "Should have correct date")
        XCTAssertEqual(summary.stepCount, 10000, "Should have step count from HealthKit")
        XCTAssertEqual(summary.restingHeartRate, 65, "Should have heart rate from HealthKit")
        XCTAssertNotNil(summary.sleepData, "Should have sleep data")
        XCTAssertEqual(summary.sleepData?.sleepEfficiency, 0.875, "Should have correct sleep efficiency")
        XCTAssertEqual(summary.remoteMetrics.count, 2, "Should have 2 remote metrics")
        XCTAssertTrue(summary.hasCompleteData, "Should have complete data")
        
        // Verify calculated properties
        XCTAssertEqual(summary.sleepEfficiency, 0.875, "Should calculate sleep efficiency")
        XCTAssertEqual(summary.totalSleepHours, 7.0, "Should calculate 7 hours of sleep")
    }

    func testExecute_HealthKitFailure() async throws {
        // Given: HealthKit throws error while API succeeds
        mockHealthKitService.shouldSucceed = false
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthDataHandler = { _, _ in
            return PaginatedMetricsResponseDTO(
                metrics: [],
                pagination: PaginationInfoDTO(
                    page: 1,
                    limit: 10,
                    totalPages: 0,
                    totalCount: 0,
                    hasNextPage: false,
                    hasPreviousPage: false
                ),
                metadata: nil
            )
        }

        // When/Then: Should throw HealthKit error
        do {
            _ = try await fetchDailyHealthSummaryUseCase.execute(for: Date())
            XCTFail("Expected HealthKit error to be thrown")
        } catch {
            XCTAssertTrue(error is HealthKitError, "Should throw HealthKitError")
        }
    }

    func testExecute_NoData() async throws {
        // Given: Both services return empty/zero data
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 0,
            restingHeartRate: nil,
            activeCalories: 0,
            exerciseMinutes: 0,
            standHours: 0,
            sleepData: nil
        )
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthDataHandler = { _, _ in
            return PaginatedMetricsResponseDTO(
                metrics: [],
                pagination: PaginationInfoDTO(
                    page: 1,
                    limit: 10,
                    totalPages: 0,
                    totalCount: 0,
                    hasNextPage: false,
                    hasPreviousPage: false
                ),
                metadata: nil
            )
        }

        // When: Execute with no data
        let summary = try await fetchDailyHealthSummaryUseCase.execute(for: Date())

        // Then: Verify summary reflects no data
        XCTAssertNotNil(summary, "Should return a summary even with no data")
        XCTAssertEqual(summary.stepCount, 0, "Should have 0 steps")
        XCTAssertNil(summary.restingHeartRate, "Should have no heart rate")
        XCTAssertNil(summary.sleepData, "Should have no sleep data")
        XCTAssertEqual(summary.remoteMetrics.count, 0, "Should have no remote metrics")
        XCTAssertFalse(summary.hasCompleteData, "Should not have complete data")
        XCTAssertNil(summary.sleepEfficiency, "Should have no sleep efficiency")
        XCTAssertNil(summary.totalSleepHours, "Should have no sleep hours")
    }
    
    // MARK: - Additional Tests
    
    func testExecute_PartialData() async throws {
        // Given: HealthKit has partial data (steps only)
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 5000,
            restingHeartRate: nil,
            activeCalories: 200,
            exerciseMinutes: 20,
            standHours: 5,
            sleepData: nil
        )
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthDataHandler = { _, _ in
            return PaginatedMetricsResponseDTO(
                metrics: [],
                pagination: PaginationInfoDTO(
                    page: 1,
                    limit: 10,
                    totalPages: 0,
                    totalCount: 0,
                    hasNextPage: false,
                    hasPreviousPage: false
                ),
                metadata: nil
            )
        }
        
        // When: Execute with partial data
        let summary = try await fetchDailyHealthSummaryUseCase.execute(for: Date())
        
        // Then: Should still have complete data flag due to steps
        XCTAssertEqual(summary.stepCount, 5000, "Should have 5000 steps")
        XCTAssertNil(summary.restingHeartRate, "Should have no heart rate")
        XCTAssertNil(summary.sleepData, "Should have no sleep data")
        XCTAssertTrue(summary.hasCompleteData, "Should have complete data due to steps > 0")
    }
    
    func testExecute_APIFailure() async throws {
        // Given: HealthKit succeeds but API fails
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 8000,
            restingHeartRate: 70,
            activeCalories: 300,
            exerciseMinutes: 30,
            standHours: 8,
            sleepData: nil
        )
        
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.networkError(URLError(.notConnectedToInternet))
        
        // When/Then: Should throw API error
        do {
            _ = try await fetchDailyHealthSummaryUseCase.execute(for: Date())
            XCTFail("Expected API error to be thrown")
        } catch {
            XCTAssertTrue(error is APIError, "Should throw APIError")
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError:
                    XCTAssertTrue(true, "Correct error type")
                default:
                    XCTFail("Wrong API error type: \(apiError)")
                }
            }
        }
    }
}
