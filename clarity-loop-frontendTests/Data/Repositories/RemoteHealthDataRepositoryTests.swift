@testable import clarity_loop_frontend
import XCTest

final class RemoteHealthDataRepositoryTests: XCTestCase {
    // MARK: - Properties
    
    var healthDataRepository: RemoteHealthDataRepository!
    var mockAPIClient: MockAPIClient!

    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPIClient = MockAPIClient()
        healthDataRepository = RemoteHealthDataRepository(apiClient: mockAPIClient)
    }

    override func tearDownWithError() throws {
        healthDataRepository = nil
        mockAPIClient = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testFetchHealthData_Success() async throws {
        // Given: Configure mockAPIClient to return health data
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthDataHandler = { page, limit in
            let metrics = [
                HealthMetricDTO(
                    id: UUID(),
                    userId: "test-user",
                    metricType: "steps",
                    timestamp: Date(),
                    metadata: nil,
                    activityData: ActivityDataDTO(
                        steps: 10000,
                        distance: 8.5,
                        floorsClimbed: 15,
                        activeCalories: 450,
                        exerciseMinutes: 60
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
                    timestamp: Date(),
                    metadata: nil,
                    activityData: nil,
                    biometricData: BiometricDataDTO(
                        heartRate: 72,
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
            ]
            
            return PaginatedMetricsResponseDTO(
                metrics: metrics,
                pagination: PaginationInfoDTO(
                    page: page,
                    limit: limit,
                    totalPages: 5,
                    totalCount: 100,
                    hasNextPage: page < 5,
                    hasPreviousPage: page > 1
                ),
                metadata: ResponseMetadataDTO(
                    requestId: "test-request-123",
                    timestamp: Date(),
                    version: "1.0"
                )
            )
        }
        
        // When: Fetch health data
        let response = try await healthDataRepository.getHealthData(page: 1, limit: 20)
        
        // Then: Verify response
        XCTAssertEqual(response.metrics.count, 2, "Should have 2 metrics")
        XCTAssertEqual(response.pagination.page, 1, "Should be page 1")
        XCTAssertEqual(response.pagination.limit, 20, "Should have limit 20")
        XCTAssertEqual(response.pagination.totalCount, 100, "Should have 100 total metrics")
        XCTAssertTrue(response.pagination.hasNextPage, "Should have next page")
        XCTAssertFalse(response.pagination.hasPreviousPage, "Should not have previous page")
        
        // Verify metric details
        let stepMetric = response.metrics.first { $0.metricType == "steps" }
        XCTAssertNotNil(stepMetric, "Should have step metric")
        XCTAssertEqual(stepMetric?.activityData?.steps, 10000, "Should have 10000 steps")
        
        let heartRateMetric = response.metrics.first { $0.metricType == "heart_rate" }
        XCTAssertNotNil(heartRateMetric, "Should have heart rate metric")
        XCTAssertEqual(heartRateMetric?.biometricData?.heartRate, 72, "Should have 72 bpm")
    }

    func testFetchHealthData_Failure() async throws {
        // Given: Configure mockAPIClient to return an error
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.networkError(URLError(.notConnectedToInternet))
        
        // When/Then: Fetch should throw error
        do {
            _ = try await healthDataRepository.getHealthData(page: 1, limit: 20)
            XCTFail("Expected network error to be thrown")
        } catch {
            XCTAssertTrue(error is APIError, "Should throw APIError")
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError:
                    XCTAssertTrue(true, "Correct error type")
                default:
                    XCTFail("Wrong error type: \(apiError)")
                }
            }
        }
    }

    func testUploadHealthData_Success() async throws {
        // Given: Configure mockAPIClient for a successful health data upload
        mockAPIClient.shouldSucceed = true
        let expectedUploadId = UUID().uuidString
        
        mockAPIClient.uploadHealthKitDataHandler = { request in
            return HealthKitUploadResponseDTO(
                uploadId: expectedUploadId,
                status: "completed",
                processedSamples: request.samples.count,
                errors: nil,
                timestamp: Date()
            )
        }
        
        // Prepare upload request
        let uploadRequest = HealthKitUploadRequestDTO(
            userId: "test-user",
            samples: [
                HealthKitSampleDTO(
                    sampleType: "stepCount",
                    value: 12000,
                    categoryValue: nil,
                    unit: "count",
                    startDate: Date().addingTimeInterval(-3600),
                    endDate: Date(),
                    metadata: nil,
                    sourceRevision: SourceRevisionDTO(
                        source: SourceDTO(
                            name: "CLARITY Pulse",
                            bundleIdentifier: "com.clarity.pulse"
                        ),
                        version: "1.0",
                        productType: "iPhone",
                        operatingSystemVersion: "17.0"
                    )
                ),
                HealthKitSampleDTO(
                    sampleType: "heartRate",
                    value: 75,
                    categoryValue: nil,
                    unit: "bpm",
                    startDate: Date(),
                    endDate: Date(),
                    metadata: nil,
                    sourceRevision: nil
                )
            ],
            deviceInfo: DeviceInfoDTO(
                deviceModel: "iPhone 15",
                systemName: "iOS",
                systemVersion: "17.0",
                appVersion: "1.0",
                timeZone: "America/New_York"
            ),
            timestamp: Date()
        )
        
        // When: Upload health data
        let response = try await healthDataRepository.uploadHealthKitData(requestDTO: uploadRequest)
        
        // Then: Verify successful upload
        XCTAssertEqual(response.uploadId, expectedUploadId, "Should have correct upload ID")
        XCTAssertEqual(response.status, "completed", "Upload should be completed")
        XCTAssertEqual(response.processedSamples, 2, "Should process 2 samples")
        XCTAssertNil(response.errors, "Should have no errors")
    }

    func testUploadHealthData_Failure() async throws {
        // Given: Configure mockAPIClient to return an error on upload
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.serverError(500, "Internal server error")
        
        // Prepare upload request
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
            deviceInfo: nil,
            timestamp: Date()
        )
        
        // When/Then: Upload should throw error
        do {
            _ = try await healthDataRepository.uploadHealthKitData(requestDTO: uploadRequest)
            XCTFail("Expected server error to be thrown")
        } catch {
            XCTAssertTrue(error is APIError, "Should throw APIError")
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let code, let message):
                    XCTAssertEqual(code, 500, "Should be 500 error")
                    XCTAssertEqual(message, "Internal server error", "Should have correct error message")
                default:
                    XCTFail("Wrong error type: \(apiError)")
                }
            }
        }
    }
    
    // MARK: - Additional Tests
    
    func testSyncHealthKitData() async throws {
        // Given: Configure mock for sync
        mockAPIClient.shouldSucceed = true
        mockAPIClient.syncHealthKitDataHandler = { request in
            return HealthKitSyncResponseDTO(
                syncId: UUID().uuidString,
                status: "in_progress",
                startDate: request.startDate,
                endDate: request.endDate,
                metricsToSync: request.metricTypes?.count ?? 0,
                syncedMetrics: 0,
                errors: nil,
                estimatedTimeRemaining: 30,
                timestamp: Date()
            )
        }
        
        // When: Sync health data
        let syncRequest = HealthKitSyncRequestDTO(
            startDate: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            endDate: Date(),
            metricTypes: ["steps", "heartRate", "sleep"],
            forceSync: true
        )
        
        let response = try await healthDataRepository.syncHealthKitData(requestDTO: syncRequest)
        
        // Then: Verify sync initiated
        XCTAssertNotNil(response.syncId, "Should have sync ID")
        XCTAssertEqual(response.status, "in_progress", "Sync should be in progress")
        XCTAssertEqual(response.metricsToSync, 3, "Should sync 3 metric types")
        XCTAssertEqual(response.syncedMetrics, 0, "Should not have synced metrics yet")
        XCTAssertEqual(response.estimatedTimeRemaining, 30, "Should estimate 30 seconds")
    }
    
    func testGetSyncStatus() async throws {
        // Given: Configure mock for sync status
        let syncId = UUID().uuidString
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthKitSyncStatusHandler = { id in
            XCTAssertEqual(id, syncId, "Should check correct sync ID")
            return HealthKitSyncStatusDTO(
                syncId: id,
                status: "completed",
                progress: 1.0,
                syncedMetrics: 150,
                totalMetrics: 150,
                errors: nil,
                completedAt: Date(),
                timestamp: Date()
            )
        }
        
        // When: Get sync status
        let status = try await healthDataRepository.getHealthKitSyncStatus(syncId: syncId)
        
        // Then: Verify completed status
        XCTAssertEqual(status.syncId, syncId, "Should have correct sync ID")
        XCTAssertEqual(status.status, "completed", "Sync should be completed")
        XCTAssertEqual(status.progress, 1.0, "Progress should be 100%")
        XCTAssertEqual(status.syncedMetrics, 150, "Should have synced all metrics")
        XCTAssertNil(status.errors, "Should have no errors")
        XCTAssertNotNil(status.completedAt, "Should have completion date")
    }
    
    func testGetUploadStatus() async throws {
        // Given: Configure mock for upload status
        let uploadId = UUID().uuidString
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getHealthKitUploadStatusHandler = { id in
            XCTAssertEqual(id, uploadId, "Should check correct upload ID")
            return HealthKitUploadStatusDTO(
                uploadId: id,
                status: "processing",
                processedSamples: 45,
                totalSamples: 100,
                errors: nil,
                timestamp: Date()
            )
        }
        
        // When: Get upload status
        let status = try await healthDataRepository.getHealthKitUploadStatus(uploadId: uploadId)
        
        // Then: Verify processing status
        XCTAssertEqual(status.uploadId, uploadId, "Should have correct upload ID")
        XCTAssertEqual(status.status, "processing", "Upload should be processing")
        XCTAssertEqual(status.processedSamples, 45, "Should have processed 45 samples")
        XCTAssertEqual(status.totalSamples, 100, "Should have 100 total samples")
    }
    
    func testGetProcessingStatus() async throws {
        // Given: Configure mock for processing status
        let processingId = UUID()
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getProcessingStatusHandler = { id in
            XCTAssertEqual(id, processingId, "Should check correct processing ID")
            return HealthDataProcessingStatusDTO(
                id: id,
                status: "completed",
                stage: "analysis",
                progress: 1.0,
                startedAt: Date().addingTimeInterval(-120),
                completedAt: Date(),
                results: ProcessingResultsDTO(
                    metricsProcessed: 250,
                    insightsGenerated: 5,
                    anomaliesDetected: 2,
                    processingTime: 120
                ),
                errors: nil,
                timestamp: Date()
            )
        }
        
        // When: Get processing status
        let status = try await healthDataRepository.getProcessingStatus(id: processingId)
        
        // Then: Verify completed processing
        XCTAssertEqual(status.id, processingId, "Should have correct processing ID")
        XCTAssertEqual(status.status, "completed", "Processing should be completed")
        XCTAssertEqual(status.stage, "analysis", "Should be in analysis stage")
        XCTAssertEqual(status.progress, 1.0, "Progress should be 100%")
        XCTAssertNotNil(status.results, "Should have results")
        XCTAssertEqual(status.results?.metricsProcessed, 250, "Should have processed 250 metrics")
        XCTAssertEqual(status.results?.insightsGenerated, 5, "Should have generated 5 insights")
    }
}
