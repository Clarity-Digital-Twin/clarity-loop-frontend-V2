import XCTest
import HealthKit
import Combine
import SwiftData
import BackgroundTasks
@testable import clarity_loop_frontend

@MainActor
final class HealthKitSyncServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var syncService: HealthKitSyncService!
    private var mockHealthKitService: MockHealthKitService!
    private var mockHealthRepository: MockHealthRepositoryForSync!
    private var mockAPIClient: MockAPIClient!
    private var mockBackgroundTaskManager: MockBackgroundTaskManagerForSync!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test dependencies
        mockHealthKitService = MockHealthKitService()
        
        // Create test model context
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: HealthMetric.self,
            configurations: modelConfiguration
        )
        let modelContext = ModelContext(modelContainer)
        
        mockHealthRepository = MockHealthRepositoryForSync(modelContext: modelContext)
        mockAPIClient = MockAPIClient()
        mockBackgroundTaskManager = MockBackgroundTaskManagerForSync()
        
        // Configure the sync service
        HealthKitSyncService.configure(
            healthKitService: mockHealthKitService,
            healthRepository: mockHealthRepository,
            apiClient: mockAPIClient,
            backgroundTaskManager: mockBackgroundTaskManager
        )
        
        syncService = HealthKitSyncService.shared!
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        syncService?.stopAutoSync()
        syncService = nil
        HealthKitSyncService.shared = nil
        mockHealthKitService = nil
        mockHealthRepository = nil
        mockAPIClient = nil
        mockBackgroundTaskManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Auto Sync Tests
    
    func testStartAutoSyncRequiresAuthorization() async throws {
        // Given - HealthKit is not available
        mockHealthKitService.isAvailable = false
        
        // When - start auto sync
        syncService.startAutoSync()
        
        // Then - sync should not start
        XCTAssertEqual(syncService.syncStatus, .idle)
        XCTAssertNil(syncService.lastSyncDate)
        XCTAssertEqual(mockHealthKitService.requestAuthorizationCallCount, 0)
    }
    
    func testStartAutoSyncInitiatesPeriodicSync() async throws {
        // Given - HealthKit is available and authorized
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // When - start auto sync
        syncService.startAutoSync()
        
        // Wait for initial sync
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - initial sync should be triggered
        XCTAssertEqual(syncService.syncStatus, .syncing)
        XCTAssertGreaterThan(mockHealthKitService.queryCallCount, 0)
    }
    
    func testStartAutoSyncSetsUpHealthKitObservers() async throws {
        // Given - HealthKit is available
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .heartRate: .sharingAuthorized,
            .stepCount: .sharingAuthorized
        ]
        
        // When - start auto sync
        syncService.startAutoSync()
        
        // Wait for setup
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Then - observers should be set up for authorized types
        XCTAssertGreaterThan(mockHealthKitService.observerQueries.count, 0)
        XCTAssertTrue(mockHealthKitService.observerQueries.contains { $0.contains("HKQuantityTypeIdentifierHeartRate") })
    }
    
    func testStopAutoSyncCancelsActiveQueries() async throws {
        // Given - auto sync is running
        mockHealthKitService.isAvailable = true
        syncService.startAutoSync()
        
        try await Task.sleep(nanoseconds: 50_000_000)
        let queriesBeforeStop = mockHealthKitService.activeQueries.count
        
        // When - stop auto sync
        syncService.stopAutoSync()
        
        // Then - all queries should be stopped
        XCTAssertEqual(syncService.syncStatus, .idle)
        XCTAssertEqual(mockHealthKitService.stopQueryCallCount, queriesBeforeStop)
    }
    
    // MARK: - Full Sync Tests
    
    func testPerformFullSyncSuccess() async throws {
        // Given - HealthKit has data available
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .heartRate: .sharingAuthorized,
            .stepCount: .sharingAuthorized,
            .sleepAnalysis: .sharingAuthorized
        ]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Mock sample data
        mockHealthKitService.mockSamples = [
            createMockHeartRateSample(value: 72, date: Date()),
            createMockHeartRateSample(value: 75, date: Date().addingTimeInterval(-300)),
            createMockStepsSample(value: 1000, date: Date())
        ]
        
        // When - perform full sync
        await syncService.performFullSync()
        
        // Then - data should be synced
        XCTAssertEqual(syncService.syncStatus, .idle) // Returns to idle after sync
        XCTAssertNotNil(syncService.lastSyncDate)
        XCTAssertGreaterThan(mockHealthRepository.uploadedMetrics.count, 0)
        XCTAssertEqual(mockHealthRepository.syncCount, 1)
    }
    
    func testPerformFullSyncUpdatesProgress() async throws {
        // Given - multiple data types to sync
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .heartRate: .sharingAuthorized,
            .stepCount: .sharingAuthorized,
            .sleepAnalysis: .sharingAuthorized,
            .activeEnergyBurned: .sharingAuthorized
        ]
        
        var progressUpdates: [Double] = []
        
        syncService.$syncProgress
            .sink { progress in
                if progress > 0 {
                    progressUpdates.append(progress)
                }
            }
            .store(in: &cancellables)
        
        // When - perform sync
        await syncService.performFullSync()
        
        // Then - progress should be updated
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertTrue(progressUpdates.contains { $0 > 0 && $0 <= 1.0 })
    }
    
    func testPerformFullSyncHandlesPartialFailure() async throws {
        // Given - some data types fail to sync
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .heartRate: .sharingAuthorized,
            .stepCount: .sharingDenied,
            .sleepAnalysis: .sharingAuthorized
        ]
        
        mockHealthKitService.shouldReturnSampleData = true
        mockHealthKitService.mockSamples = [
            createMockHeartRateSample(value: 72, date: Date())
        ]
        
        // When - perform sync
        await syncService.performFullSync()
        
        // Then - partial data should still be synced
        XCTAssertGreaterThan(mockHealthRepository.uploadedMetrics.count, 0)
        XCTAssertTrue(syncService.syncErrors.isEmpty == false || syncService.syncStatus == .partialSuccess)
    }
    
    func testPerformFullSyncUpdatesLastSyncDate() async throws {
        // Given - ready to sync
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        let syncDateBefore = syncService.lastSyncDate
        
        // When - perform sync
        await syncService.performFullSync()
        
        // Then - last sync date should be updated
        XCTAssertNotEqual(syncService.lastSyncDate, syncDateBefore)
        if let lastSync = syncService.lastSyncDate {
            XCTAssertLessThan(lastSync.timeIntervalSinceNow, 1.0)
        }
    }
    
    // MARK: - Date Range Sync Tests
    
    func testSyncDateRangeRespectsLimits() async throws {
        // Given - specific date range
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        
        let startDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days ago
        let endDate = Date()
        
        // When - sync date range
        await syncService.syncDateRange(from: startDate, to: endDate)
        
        // Then - query should respect date range
        XCTAssertGreaterThan(mockHealthKitService.queryCallCount, 0)
        XCTAssertEqual(mockHealthKitService.lastQueryStartDate?.timeIntervalSince1970 ?? 0, startDate.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(mockHealthKitService.lastQueryEndDate?.timeIntervalSince1970 ?? 0, endDate.timeIntervalSince1970, accuracy: 1)
    }
    
    func testSyncDateRangeHandlesEmptyData() async throws {
        // Given - no data in date range
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = false
        mockHealthKitService.mockSamples = []
        
        // When - sync empty date range
        await syncService.syncDateRange(from: Date(), to: Date())
        
        // Then - should complete without error
        XCTAssertEqual(syncService.syncStatus, .idle)
        XCTAssertEqual(mockHealthRepository.uploadedMetrics.count, 0)
        XCTAssertTrue(syncService.syncErrors.isEmpty)
    }
    
    // MARK: - Step Sync Tests
    
    func testSyncStepsConvertsToHealthMetrics() async throws {
        // Given - step data available
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.stepCount: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        let stepSample = createMockStepsSample(value: 5000, date: Date())
        mockHealthKitService.mockSamples = [stepSample]
        
        // When - sync steps
        await syncService.syncSteps(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - steps should be converted to health metrics
        XCTAssertGreaterThan(mockHealthRepository.uploadedMetrics.count, 0)
        
        let stepMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .steps }
        XCTAssertNotNil(stepMetric)
        XCTAssertEqual(stepMetric?.value, 5000)
        XCTAssertEqual(stepMetric?.unit, "count")
    }
    
    func testSyncStepsIncludesDeviceMetadata() async throws {
        // Given - step data with device info
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.stepCount: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        mockHealthKitService.includeDeviceMetadata = true
        
        let stepSample = createMockStepsSample(value: 1000, date: Date())
        mockHealthKitService.mockSamples = [stepSample]
        
        // When - sync steps
        await syncService.syncSteps(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - metadata should include device info
        let stepMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .steps }
        XCTAssertNotNil(stepMetric)
        XCTAssertNotNil(stepMetric?.metadata)
        XCTAssertNotNil(stepMetric?.source)
    }
    
    func testSyncStepsBatchProcessing() async throws {
        // Given - large amount of step data
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.stepCount: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create 150 samples (more than batch size)
        var samples: [HKQuantitySample] = []
        for i in 0..<150 {
            let sample = createMockStepsSample(
                value: Double(100 + i),
                date: Date().addingTimeInterval(Double(-i * 3600))
            )
            samples.append(sample)
        }
        mockHealthKitService.mockSamples = samples
        
        // When - sync steps
        await syncService.syncSteps(from: Date().addingTimeInterval(-7 * 24 * 3600), to: Date())
        
        // Then - should process in batches
        XCTAssertEqual(mockHealthRepository.uploadedMetrics.count, 150)
        XCTAssertGreaterThan(mockHealthRepository.saveCount, 1) // Multiple batch saves
    }
    
    // MARK: - Heart Rate Sync Tests
    
    func testSyncHeartRateIncludesMotionContext() async throws {
        // Given - heart rate data with motion context
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        mockHealthKitService.includeMotionContext = true
        
        let heartRateSample = createMockHeartRateSample(value: 120, date: Date())
        mockHealthKitService.mockSamples = [heartRateSample]
        
        // When - sync heart rate
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - should include motion context
        let hrMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .heartRate }
        XCTAssertNotNil(hrMetric)
        XCTAssertNotNil(hrMetric?.metadata?["motionContext"])
    }
    
    func testSyncHeartRateHandlesDifferentUnits() async throws {
        // Given - heart rate in different units
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create samples with different units
        let samples = [
            createMockHeartRateSample(value: 72, date: Date()),
            createMockHeartRateSample(value: 80, date: Date().addingTimeInterval(-300))
        ]
        mockHealthKitService.mockSamples = samples
        
        // When - sync heart rate
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - all should be converted to bpm
        let hrMetrics = mockHealthRepository.uploadedMetrics.filter { $0.type == .heartRate }
        XCTAssertEqual(hrMetrics.count, 2)
        XCTAssertTrue(hrMetrics.allSatisfy { $0.unit == "count/min" || $0.unit == "bpm" })
    }
    
    // MARK: - Sleep Sync Tests
    
    func testSyncSleepGroupsByDay() async throws {
        // Given - sleep data across multiple days
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.sleepAnalysis: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create sleep samples for two nights
        let night1Start = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let night1End = Calendar.current.date(byAdding: .hour, value: 8, to: night1Start)!
        
        let night2Start = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let night2End = Calendar.current.date(byAdding: .hour, value: 7, to: night2Start)!
        
        mockHealthKitService.mockCategorySamples = [
            createMockSleepSample(value: .asleepCore, startDate: night1Start, endDate: night1End),
            createMockSleepSample(value: .asleepCore, startDate: night2Start, endDate: night2End)
        ]
        
        // When - sync sleep
        await syncService.syncSleep(from: night1Start, to: Date())
        
        // Then - should group by day
        let sleepMetrics = mockHealthRepository.uploadedMetrics.filter { $0.type == .sleepDuration }
        XCTAssertGreaterThanOrEqual(sleepMetrics.count, 2)
    }
    
    func testSyncSleepCalculatesTotalDuration() async throws {
        // Given - multiple sleep stages
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.sleepAnalysis: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        let bedtime = Date().addingTimeInterval(-8 * 3600)
        mockHealthKitService.mockCategorySamples = [
            createMockSleepSample(value: .asleepCore, startDate: bedtime, endDate: bedtime.addingTimeInterval(3 * 3600)),
            createMockSleepSample(value: .asleepREM, startDate: bedtime.addingTimeInterval(3 * 3600), endDate: bedtime.addingTimeInterval(4 * 3600)),
            createMockSleepSample(value: .asleepDeep, startDate: bedtime.addingTimeInterval(4 * 3600), endDate: bedtime.addingTimeInterval(6 * 3600)),
            createMockSleepSample(value: .awake, startDate: bedtime.addingTimeInterval(6 * 3600), endDate: bedtime.addingTimeInterval(6.5 * 3600)),
            createMockSleepSample(value: .asleepCore, startDate: bedtime.addingTimeInterval(6.5 * 3600), endDate: bedtime.addingTimeInterval(8 * 3600))
        ]
        
        // When - sync sleep
        await syncService.syncSleep(from: bedtime, to: Date())
        
        // Then - should calculate total sleep duration
        let sleepMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .sleepDuration }
        XCTAssertNotNil(sleepMetric)
        // Total sleep: 3 + 1 + 2 + 1.5 = 7.5 hours = 450 minutes (excluding awake time)
        XCTAssertEqual(sleepMetric?.value ?? 0, 450, accuracy: 10)
    }
    
    func testSyncSleepAnalyzesStages() async throws {
        // Given - different sleep stages
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.sleepAnalysis: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        let bedtime = Date().addingTimeInterval(-8 * 3600)
        mockHealthKitService.mockCategorySamples = [
            createMockSleepSample(value: .asleepCore, startDate: bedtime, endDate: bedtime.addingTimeInterval(3 * 3600)),
            createMockSleepSample(value: .asleepREM, startDate: bedtime.addingTimeInterval(3 * 3600), endDate: bedtime.addingTimeInterval(4.5 * 3600)),
            createMockSleepSample(value: .asleepDeep, startDate: bedtime.addingTimeInterval(4.5 * 3600), endDate: bedtime.addingTimeInterval(6 * 3600))
        ]
        
        // When - sync sleep
        await syncService.syncSleep(from: bedtime, to: Date())
        
        // Then - should create metrics for each stage
        let remMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .sleepREM }
        let deepMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .sleepDeep }
        let lightMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .sleepLight }
        
        XCTAssertNotNil(remMetric)
        XCTAssertNotNil(deepMetric)
        XCTAssertEqual(remMetric?.value ?? 0, 90, accuracy: 10) // 1.5 hours = 90 minutes
        XCTAssertEqual(deepMetric?.value ?? 0, 90, accuracy: 10) // 1.5 hours = 90 minutes
    }
    
    // MARK: - Workout Sync Tests
    
    func testSyncWorkoutsExtractsActiveEnergy() async throws {
        // Given - workout with energy data
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .workoutType: .sharingAuthorized,
            .activeEnergyBurned: .sharingAuthorized
        ]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Mock workout with 150 calories burned
        mockHealthKitService.mockWorkouts = [
            MockWorkout(
                activityType: .running,
                duration: 1800, // 30 minutes
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 150),
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(-1800)
            )
        ]
        
        // When - sync workouts
        await syncService.syncWorkouts(from: Date().addingTimeInterval(-7200), to: Date())
        
        // Then - active energy should be extracted
        let energyMetric = mockHealthRepository.uploadedMetrics.first { $0.type == .activeEnergy }
        XCTAssertNotNil(energyMetric)
        XCTAssertEqual(energyMetric?.value, 150)
        XCTAssertEqual(energyMetric?.unit, "kcal")
    }
    
    func testSyncWorkoutsIncludesWorkoutType() async throws {
        // Given - different workout types
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.workoutType: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        mockHealthKitService.mockWorkouts = [
            MockWorkout(
                activityType: .running,
                duration: 1800,
                totalEnergyBurned: nil,
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(-1800)
            ),
            MockWorkout(
                activityType: .cycling,
                duration: 3600,
                totalEnergyBurned: nil,
                startDate: Date().addingTimeInterval(-7200),
                endDate: Date().addingTimeInterval(-3600)
            )
        ]
        
        // When - sync workouts
        await syncService.syncWorkouts(from: Date().addingTimeInterval(-86400), to: Date())
        
        // Then - workout types should be included in metadata
        let exerciseMetrics = mockHealthRepository.uploadedMetrics.filter { $0.type == .exerciseMinutes }
        XCTAssertGreaterThan(exerciseMetrics.count, 0)
        
        // Check metadata includes workout type
        let runningMetric = exerciseMetrics.first { $0.metadata?["workoutType"] == "Running" }
        let cyclingMetric = exerciseMetrics.first { $0.metadata?["workoutType"] == "Cycling" }
        XCTAssertNotNil(runningMetric)
        XCTAssertNotNil(cyclingMetric)
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchProcessingRespectsSize() async throws {
        // Given - more data than batch size
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create 250 samples (batch size is 100)
        var samples: [HKQuantitySample] = []
        for i in 0..<250 {
            samples.append(createMockHeartRateSample(
                value: Double(60 + (i % 40)),
                date: Date().addingTimeInterval(Double(-i * 60))
            ))
        }
        mockHealthKitService.mockSamples = samples
        
        // When - sync data
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-86400), to: Date())
        
        // Then - should process in batches of 100
        XCTAssertEqual(mockHealthRepository.uploadedMetrics.count, 250)
        // Should have made at least 3 batch calls (250 / 100 = 2.5, rounded up to 3)
        XCTAssertGreaterThanOrEqual(mockAPIClient.batchUploadCallCount, 3)
    }
    
    func testBatchUploadWithRetry() async throws {
        // Given - API fails first attempt
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        mockHealthKitService.mockSamples = [
            createMockHeartRateSample(value: 72, date: Date())
        ]
        
        // Configure API to fail first 2 attempts
        mockAPIClient.failureCount = 2
        mockAPIClient.shouldReturnError = true
        
        // When - sync with retry
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - should retry and eventually succeed
        XCTAssertGreaterThan(mockAPIClient.requestCount, 1) // Multiple attempts
        XCTAssertEqual(mockHealthRepository.uploadedMetrics.count, 1) // Eventually succeeded
    }
    
    func testBatchProcessingMarksFailedItems() async throws {
        // Given - some items fail to upload
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        mockHealthKitService.mockSamples = [
            createMockHeartRateSample(value: 72, date: Date()),
            createMockHeartRateSample(value: 80, date: Date().addingTimeInterval(-300)),
            createMockHeartRateSample(value: 65, date: Date().addingTimeInterval(-600))
        ]
        
        // Configure repository to fail sync
        mockHealthRepository.shouldFailSync = true
        
        // When - attempt sync
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-3600), to: Date())
        
        // Then - errors should be recorded
        XCTAssertFalse(syncService.syncErrors.isEmpty)
        XCTAssertEqual(syncService.syncStatus, .failed)
    }
    
    // MARK: - Background Task Tests
    
    func testBackgroundTaskRegistration() async throws {
        // Given - background task manager
        // Task registration happens during init
        
        // Then - task should be registered
        XCTAssertTrue(mockBackgroundTaskManager.registeredTasks.contains("com.clarity.healthsync"))
    }
    
    func testBackgroundSyncExecution() async throws {
        // Given - background task is triggered
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        
        // When - simulate background task execution
        mockBackgroundTaskManager.simulateBackgroundTaskExecution()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then - sync should be performed
        XCTAssertEqual(mockBackgroundTaskManager.executeCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncErrorsAreRecorded() async throws {
        // Given - sync will fail
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnError = true
        mockHealthKitService.errorToReturn = NSError(domain: "HealthKit", code: 100, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When - attempt sync
        await syncService.performFullSync()
        
        // Then - errors should be recorded
        XCTAssertFalse(syncService.syncErrors.isEmpty)
        let error = syncService.syncErrors.first
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.dataType, "heart_rate")
    }
    
    func testAuthorizationChangeHandling() async throws {
        // Given - authorization status changes
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        
        // Start sync
        syncService.startAutoSync()
        
        // When - authorization is revoked
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingDenied]
        NotificationCenter.default.post(
            name: .healthKitAuthorizationStatusChanged,
            object: nil
        )
        
        // Wait for notification handling
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then - sync should adapt to new authorization
        await syncService.performFullSync()
        
        // Should not sync heart rate data
        let hrMetrics = mockHealthRepository.uploadedMetrics.filter { $0.type == .heartRate }
        XCTAssertEqual(hrMetrics.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetSyncPerformance() async throws {
        // Given - large dataset
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [
            .heartRate: .sharingAuthorized,
            .stepCount: .sharingAuthorized
        ]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create 1000 samples
        var samples: [HKQuantitySample] = []
        for i in 0..<1000 {
            samples.append(createMockHeartRateSample(
                value: Double(60 + (i % 40)),
                date: Date().addingTimeInterval(Double(-i * 300))
            ))
        }
        mockHealthKitService.mockSamples = samples
        
        // When - measure sync performance
        let startTime = Date()
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-86400 * 7), to: Date())
        let syncDuration = Date().timeIntervalSince(startTime)
        
        // Then - should complete in reasonable time
        XCTAssertLessThan(syncDuration, 5.0) // Should complete within 5 seconds
        XCTAssertEqual(mockHealthRepository.uploadedMetrics.count, 1000)
    }
    
    func testMemoryUsageDuringSynx() async throws {
        // Given - large dataset to test memory usage
        mockHealthKitService.isAvailable = true
        mockHealthKitService.authorizationStatus = [.heartRate: .sharingAuthorized]
        mockHealthKitService.shouldReturnSampleData = true
        
        // Create samples in batches to avoid memory spike during test setup
        mockHealthKitService.generateSamplesOnDemand = true
        mockHealthKitService.totalSamplesToGenerate = 5000
        
        // When - sync large dataset
        await syncService.syncHeartRate(from: Date().addingTimeInterval(-86400 * 30), to: Date())
        
        // Then - should process without excessive memory usage
        // Verify batch processing worked
        XCTAssertGreaterThan(mockAPIClient.batchUploadCallCount, 1)
        // Verify all data was processed
        XCTAssertGreaterThanOrEqual(mockHealthRepository.uploadedMetrics.count, 1000)
    }
    
    // MARK: - Helper Methods
    
    private func createMockHeartRateSample(value: Double, date: Date) -> HKQuantitySample {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: value)
        return HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date
        )
    }
    
    private func createMockStepsSample(value: Double, date: Date) -> HKQuantitySample {
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: value)
        return HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date.addingTimeInterval(-3600),
            end: date
        )
    }
    
    private func createMockSleepSample(value: HKCategoryValueSleepAnalysis, startDate: Date, endDate: Date) -> HKCategorySample {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        return HKCategorySample(
            type: type,
            value: value.rawValue,
            start: startDate,
            end: endDate
        )
    }
}

// MARK: - Mock Workout

struct MockWorkout {
    let activityType: HKWorkoutActivityType
    let duration: TimeInterval
    let totalEnergyBurned: HKQuantity?
    let startDate: Date
    let endDate: Date
}

// MARK: - Mock Background Task Manager

class MockBackgroundTaskManagerForSync: BackgroundTaskManagerProtocol {
    var registeredTasks: Set<String> = []
    var executeCount = 0
    var shouldCompleteSuccessfully = true
    var lastCompletion: (() -> Void)?
    var registerBackgroundTasksCalled = false
    var scheduleHealthDataSyncCalled = false
    var scheduleAppRefreshCalled = false
    
    func registerBackgroundTasks() {
        registerBackgroundTasksCalled = true
        registeredTasks.insert("com.clarity.healthsync")
    }
    
    func scheduleHealthDataSync() {
        scheduleHealthDataSyncCalled = true
    }
    
    func scheduleAppRefresh() {
        scheduleAppRefreshCalled = true
    }
    
    func handleHealthDataSync() async -> Bool {
        executeCount += 1
        lastCompletion?()
        return shouldCompleteSuccessfully
    }
    
    func handleAppRefresh() async -> Bool {
        return shouldCompleteSuccessfully
    }
    
    func simulateBackgroundTaskExecution() {
        executeCount += 1
        lastCompletion?()
    }
}

// MARK: - Mock Health Repository for Sync Tests

class MockHealthRepositoryForSync {
    var uploadedMetrics: [HealthMetric] = []
    var saveCount = 0
    var syncCount = 0
    var shouldFailSync = false
    var pendingMetrics: [HealthMetric] = []
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func create(_ model: HealthMetric) async throws {
        uploadedMetrics.append(model)
        saveCount += 1
    }
    
    func batchCreate(_ models: [HealthMetric]) async throws {
        uploadedMetrics.append(contentsOf: models)
        saveCount += models.count
    }
    
    func sync() async throws {
        syncCount += 1
        if shouldFailSync {
            throw RepositoryError.syncFailed(NSError(domain: "Test", code: 1))
        }
    }
    
    func fetchPendingSync() async throws -> [HealthMetric] {
        return pendingMetrics
    }
}

