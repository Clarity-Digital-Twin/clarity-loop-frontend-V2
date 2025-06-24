@testable import clarity_loop_frontend
import XCTest

final class SyncHealthDataUseCaseTests: XCTestCase {
    // MARK: - Properties
    
    var syncHealthDataUseCase: SyncHealthDataUseCase!
    var mockHealthKitService: MockHealthKitService!
    var mockHealthDataRepository: MockHealthDataRepository!
    var mockAPIClient: MockAPIClient!
    var mockAuthService: MockAuthService!

    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize mocks
        mockHealthKitService = MockHealthKitService()
        mockHealthDataRepository = MockHealthDataRepository()
        mockAPIClient = MockAPIClient()
        mockAuthService = MockAuthService()
        
        // Set up default authenticated user
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Initialize use case
        syncHealthDataUseCase = SyncHealthDataUseCase(
            healthKitService: mockHealthKitService,
            healthDataRepository: mockHealthDataRepository,
            apiClient: mockAPIClient,
            authService: mockAuthService
        )
    }

    override func tearDownWithError() throws {
        syncHealthDataUseCase = nil
        mockHealthKitService = nil
        mockHealthDataRepository = nil
        mockAPIClient = nil
        mockAuthService = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testExecute_SyncSuccess() async throws {
        // Given: HealthKit is available with data and upload succeeds
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 10000,
            restingHeartRate: 65,
            activeCalories: 350,
            exerciseMinutes: 45,
            standHours: 12,
            sleepData: SleepData(
                totalTimeInBed: 28800, // 8 hours
                totalTimeAsleep: 25200, // 7 hours
                sleepEfficiency: 0.875
            )
        )
        
        // Configure mock API client for successful upload
        mockAPIClient.shouldSucceed = true
        
        // When: Execute sync for a single day
        let endDate = Date()
        let startDate = Calendar.current.startOfDay(for: endDate)
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Verify successful sync
        XCTAssertTrue(result.isSuccess, "Sync should be successful")
        XCTAssertEqual(result.successfulDays, 1, "Should have 1 successful day")
        XCTAssertEqual(result.failedDays, 0, "Should have no failed days")
        XCTAssertGreaterThan(result.uploadedSamples, 0, "Should have uploaded samples")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
        XCTAssertEqual(result.successRate, 1.0, "Success rate should be 100%")
        
        // Verify HealthKit was called
        XCTAssertTrue(mockHealthKitService.fetchAllDailyMetricsCalled, "Should fetch daily metrics")
        XCTAssertEqual(mockHealthKitService.capturedFetchDate?.day, startDate.day, "Should fetch for correct date")
    }

    func testExecute_HealthKitFetchFails() async throws {
        // Given: HealthKit fetch throws an error
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.shouldFailFetch = true
        mockHealthKitService.fetchError = NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data"])
        
        // When: Execute sync
        let endDate = Date()
        let startDate = Calendar.current.startOfDay(for: endDate)
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Verify sync failure is handled gracefully
        XCTAssertFalse(result.isSuccess, "Sync should fail")
        XCTAssertEqual(result.successfulDays, 0, "Should have no successful days")
        XCTAssertEqual(result.failedDays, 1, "Should have 1 failed day")
        XCTAssertEqual(result.uploadedSamples, 0, "Should have no uploaded samples")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        XCTAssertTrue(result.errors.first?.contains("Failed to fetch data") ?? false, "Error should contain fetch failure message")
    }

    func testExecute_RemoteUploadFails() async throws {
        // Given: HealthKit returns data but upload fails
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 5000,
            restingHeartRate: 70,
            activeCalories: 200,
            exerciseMinutes: 30,
            standHours: 8,
            sleepData: nil
        )
        
        // Configure mock API client to fail
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.networkError(URLError(.notConnectedToInternet))
        
        // When: Execute sync
        let endDate = Date()
        let startDate = Calendar.current.startOfDay(for: endDate)
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Verify upload failure is handled
        XCTAssertFalse(result.isSuccess, "Sync should fail")
        XCTAssertEqual(result.successfulDays, 0, "Should have no successful days")
        XCTAssertEqual(result.failedDays, 1, "Should have 1 failed day")
        XCTAssertEqual(result.uploadedSamples, 0, "Should have no uploaded samples")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        XCTAssertTrue(result.errors.first?.contains("Failed to sync data") ?? false, "Error should contain sync failure message")
    }

    func testExecute_NoNewDataToSync() async throws {
        // Given: HealthKit returns empty data
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 0,
            restingHeartRate: nil,
            activeCalories: 0,
            exerciseMinutes: 0,
            standHours: 0,
            sleepData: nil
        )
        
        mockAPIClient.shouldSucceed = true
        
        // When: Execute sync
        let endDate = Date()
        let startDate = Calendar.current.startOfDay(for: endDate)
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Verify sync completes successfully even with no data
        XCTAssertTrue(result.isSuccess, "Sync should be successful even with no data")
        XCTAssertEqual(result.successfulDays, 1, "Should have 1 successful day")
        XCTAssertEqual(result.failedDays, 0, "Should have no failed days")
        // No samples should be uploaded when all values are 0 or nil
        XCTAssertEqual(result.uploadedSamples, 0, "Should have no uploaded samples when no data")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }
    
    // MARK: - Additional Tests
    
    func testExecute_HealthKitNotAvailable() async throws {
        // Given: HealthKit is not available
        mockHealthKitService.isHealthDataAvailableValue = false
        
        // When/Then: Execute sync should throw
        do {
            _ = try await syncHealthDataUseCase.execute()
            XCTFail("Should throw healthKitNotAvailable error")
        } catch {
            XCTAssertTrue(error is SyncUseCaseError, "Should throw SyncUseCaseError")
            if let syncError = error as? SyncUseCaseError {
                switch syncError {
                case .healthKitNotAvailable:
                    XCTAssertTrue(true, "Correct error thrown")
                default:
                    XCTFail("Wrong error type: \(syncError)")
                }
            }
        }
    }
    
    func testExecute_UserNotAuthenticated() async throws {
        // Given: User is not authenticated
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 1000,
            restingHeartRate: 60,
            activeCalories: 100,
            exerciseMinutes: 15,
            standHours: 5,
            sleepData: nil
        )
        mockAuthService.mockCurrentUser = nil // No authenticated user
        
        // When: Execute sync
        let result = try await syncHealthDataUseCase.execute()
        
        // Then: Sync should fail with authentication error
        XCTAssertFalse(result.isSuccess, "Sync should fail")
        XCTAssertEqual(result.failedDays, 7, "Should fail all 7 days (default range)")
        XCTAssertTrue(result.errors.first?.contains("User must be authenticated") ?? false, "Should have authentication error")
    }
    
    func testExecute_MultiDaySync() async throws {
        // Given: HealthKit has data for multiple days
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 8000,
            restingHeartRate: 68,
            activeCalories: 300,
            exerciseMinutes: 40,
            standHours: 10,
            sleepData: SleepData(
                totalTimeInBed: 27000, // 7.5 hours
                totalTimeAsleep: 25200, // 7 hours
                sleepEfficiency: 0.933
            )
        )
        mockAPIClient.shouldSucceed = true
        
        // When: Execute sync for 3 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: endDate)!
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Should sync all 3 days
        XCTAssertTrue(result.isSuccess, "Sync should be successful")
        XCTAssertEqual(result.successfulDays, 3, "Should have 3 successful days")
        XCTAssertEqual(result.failedDays, 0, "Should have no failed days")
        XCTAssertEqual(result.totalDays, 3, "Should have 3 total days")
        XCTAssertEqual(result.successRate, 1.0, "Success rate should be 100%")
    }
    
    func testExecute_PartialSuccess() async throws {
        // Given: Some days succeed and some fail
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.mockDailyMetrics = DailyHealthMetrics(
            stepCount: 7500,
            restingHeartRate: 72,
            activeCalories: 280,
            exerciseMinutes: 35,
            standHours: 9,
            sleepData: nil
        )
        
        // Mock API client to fail on second call
        var callCount = 0
        mockAPIClient.uploadHealthKitDataHandler = { _ in
            callCount += 1
            if callCount == 2 {
                throw APIError.serverError(500, "Internal server error")
            }
            return HealthKitUploadResponseDTO(
                uploadId: UUID().uuidString,
                status: "completed",
                processedSamples: 2,
                errors: nil,
                timestamp: Date()
            )
        }
        
        // When: Execute sync for 3 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: endDate)!
        let result = try await syncHealthDataUseCase.execute(startDate: startDate, endDate: endDate)
        
        // Then: Should have partial success
        XCTAssertFalse(result.isSuccess, "Sync should fail overall")
        XCTAssertEqual(result.successfulDays, 2, "Should have 2 successful days")
        XCTAssertEqual(result.failedDays, 1, "Should have 1 failed day")
        XCTAssertEqual(result.totalDays, 3, "Should have 3 total days")
        XCTAssertEqual(result.successRate, 2.0/3.0, accuracy: 0.01, "Success rate should be 66.7%")
        XCTAssertEqual(result.errors.count, 1, "Should have 1 error")
    }
}

// MARK: - Mock Health Data Repository

private class MockHealthDataRepository: HealthDataRepositoryProtocol {
    func saveHealthMetrics(_ metrics: [HealthMetric]) async throws {
        // Not used in sync use case
    }
    
    func fetchHealthMetrics(for dateRange: ClosedRange<Date>) async throws -> [HealthMetric] {
        // Not used in sync use case
        return []
    }
    
    func fetchLatestHealthMetrics(limit: Int) async throws -> [HealthMetric] {
        // Not used in sync use case
        return []
    }
    
    func deleteHealthMetrics(olderThan date: Date) async throws {
        // Not used in sync use case
    }
}
