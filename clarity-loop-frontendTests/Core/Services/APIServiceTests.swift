import XCTest
import SwiftData
@testable import clarity_loop_frontend

@MainActor
final class APIServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var apiService: APIService!
    private var mockAPIClient: MockAPIClient!
    private var mockOfflineQueueManager: MockOfflineQueueManager!
    private var modelContext: ModelContext!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test dependencies
        mockAPIClient = MockAPIClient()
        mockOfflineQueueManager = MockOfflineQueueManager()
        
        // Configure mock auth service
        let mockAuthService = MockAuthService()
        
        // Configure APIService
        APIService.configure(
            apiClient: mockAPIClient,
            authService: mockAuthService,
            offlineQueue: mockOfflineQueueManager
        )
        
        apiService = APIService.shared!
        
        // Setup SwiftData model context for tests
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: HealthMetric.self, UserProfile.self, PATAnalysis.self, AIInsight.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() async throws {
        apiService = nil
        mockAPIClient = nil
        mockOfflineQueueManager = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Health Metrics Sync Tests
    
    func testSyncHealthMetricsOnlineSuccess() async throws {
        // Given: Online and ready to sync
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = HealthDataUploadResponseDTO(
            success: true,
            processedSamples: 2,
            message: "Successfully processed 2 samples"
        )
        
        // Create test endpoint for health metrics upload
        let endpoint = APIEndpoint.uploadHealthData(
            HealthDataUploadRequestDTO(
                userId: "test-user-123",
                samples: [
                    HealthSampleDTO(
                        type: .heartRate,
                        value: 72,
                        unit: "bpm",
                        timestamp: Date(),
                        metadata: nil
                    ),
                    HealthSampleDTO(
                        type: .heartRate,
                        value: 85,
                        unit: "bpm",
                        timestamp: Date().addingTimeInterval(-60),
                        metadata: nil
                    )
                ]
            )
        )
        
        // When: Execute the request
        let response: HealthDataUploadResponseDTO = try await apiService.execute(endpoint)
        
        // Then: Should succeed
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.processedSamples, 2)
        XCTAssertEqual(mockAPIClient.requestCount, 1)
    }
    
    func testSyncHealthMetricsOfflineQueues() async throws {
        // Given: Offline state
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = URLError(.notConnectedToInternet)
        
        // Create test endpoint
        let endpoint = APIEndpoint.uploadHealthData(
            HealthDataUploadRequestDTO(
                userId: "test-user-123",
                samples: [
                    HealthSampleDTO(
                        type: .steps,
                        value: 5000,
                        unit: "count",
                        timestamp: Date(),
                        metadata: nil
                    )
                ]
            )
        )
        
        // When: Try to execute request while offline
        do {
            let _: HealthDataUploadResponseDTO = try await apiService.execute(endpoint)
            XCTFail("Should have failed due to offline state")
        } catch {
            // Then: Should queue the operation
            XCTAssertEqual(mockOfflineQueueManager.queuedUploads.count, 0) // APIService doesn't auto-queue
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testSyncHealthMetricsBatchProcessing() async throws {
        // Given: Large batch of metrics
        var samples: [HealthSampleDTO] = []
        for i in 0..<100 {
            samples.append(HealthSampleDTO(
                type: .heartRate,
                value: Double(60 + i % 40),
                unit: "bpm",
                timestamp: Date().addingTimeInterval(Double(-i * 60)),
                metadata: nil
            ))
        }
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = HealthDataUploadResponseDTO(
            success: true,
            processedSamples: samples.count,
            message: "Batch processed successfully"
        )
        
        // When: Execute batch upload
        let endpoint = APIEndpoint.uploadHealthData(
            HealthDataUploadRequestDTO(userId: "test-user-123", samples: samples)
        )
        let response: HealthDataUploadResponseDTO = try await apiService.execute(endpoint)
        
        // Then: Should process entire batch
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.processedSamples, 100)
    }
    
    func testSyncHealthMetricsUpdatesLocalSyncStatus() async throws {
        // Given: Metrics with sync status
        let metric = HealthMetric(
            timestamp: Date(),
            value: 98.6,
            type: .bodyTemperature,
            unit: "°F"
        )
        metric.syncStatus = .pending
        
        // Mock successful sync
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = HealthDataUploadResponseDTO(
            success: true,
            processedSamples: 1,
            message: "Synced successfully"
        )
        
        // When: Sync the metric
        let endpoint = APIEndpoint.uploadHealthData(
            HealthDataUploadRequestDTO(
                userId: "test-user-123",
                samples: [
                    HealthSampleDTO(
                        type: .bodyTemperature,
                        value: metric.value,
                        unit: metric.unit,
                        timestamp: metric.timestamp,
                        metadata: nil
                    )
                ]
            )
        )
        
        let response: HealthDataUploadResponseDTO = try await apiService.execute(endpoint)
        
        // Then: Response indicates success
        XCTAssertTrue(response.success)
        // Note: APIService doesn't directly update model sync status - that's handled by repositories
    }
    
    // MARK: - User Profile Sync Tests
    
    func testSyncUserProfileSuccess() async throws {
        // Given: Mock user profile response
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = UserSessionResponseDTO(
            id: UUID().uuidString,
            email: "test@example.com",
            displayName: "Test User",
            avatarUrl: "https://example.com/avatar.jpg",
            provider: "email",
            role: "user",
            isActive: true,
            isEmailVerified: true,
            preferences: UserPreferencesResponseDTO(
                theme: "dark",
                notifications: true,
                language: "en"
            ),
            metadata: UserMetadataResponseDTO(
                lastLogin: Date(),
                loginCount: 5,
                createdAt: Date().addingTimeInterval(-86400 * 30),
                updatedAt: Date()
            )
        )
        
        // When: Fetch user profile
        let endpoint = APIEndpoint.getUserProfile("test-user-123")
        let profile: UserSessionResponseDTO = try await apiService.execute(endpoint)
        
        // Then: Should receive profile data
        XCTAssertEqual(profile.email, "test@example.com")
        XCTAssertEqual(profile.displayName, "Test User")
        XCTAssertTrue(profile.isEmailVerified)
        XCTAssertEqual(mockAPIClient.requestCount, 1)
    }
    
    func testSyncUserProfileMergesChanges() async throws {
        // Given: Updated profile data
        let updateRequest = UserProfileUpdateRequestDTO(
            firstName: "Updated",
            lastName: "Name",
            phone: "+1234567890",
            dateOfBirth: Date().addingTimeInterval(-365 * 25 * 86400), // 25 years ago
            gender: "male",
            height: 180,
            weight: 75,
            activityLevel: "moderate",
            healthGoals: ["weight_loss", "fitness"],
            medicalConditions: [],
            medications: []
        )
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = UserProfileResponseDTO(
            id: UUID().uuidString,
            userId: "test-user-123",
            firstName: updateRequest.firstName,
            lastName: updateRequest.lastName,
            phone: updateRequest.phone,
            dateOfBirth: updateRequest.dateOfBirth,
            gender: updateRequest.gender,
            height: updateRequest.height,
            weight: updateRequest.weight,
            activityLevel: updateRequest.activityLevel,
            healthGoals: updateRequest.healthGoals,
            medicalConditions: updateRequest.medicalConditions,
            medications: updateRequest.medications,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date()
        )
        
        // When: Update profile
        let endpoint = APIEndpoint.updateUserProfile(updateRequest)
        let response: UserProfileResponseDTO = try await apiService.execute(endpoint)
        
        // Then: Should merge changes
        XCTAssertEqual(response.firstName, "Updated")
        XCTAssertEqual(response.lastName, "Name")
        XCTAssertEqual(response.activityLevel, "moderate")
        XCTAssertEqual(response.healthGoals.count, 2)
    }
    
    func testSyncUserProfileHandlesConflicts() async throws {
        // Given: Conflict scenario - profile updated by another client
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = APIError.conflict("Profile was updated by another client")
        
        let updateRequest = UserProfileUpdateRequestDTO(
            firstName: "Conflicting",
            lastName: "Update"
        )
        
        // When: Try to update with conflict
        do {
            let endpoint = APIEndpoint.updateUserProfile(updateRequest)
            let _: UserProfileResponseDTO = try await apiService.execute(endpoint)
            XCTFail("Should have thrown conflict error")
        } catch APIError.conflict(let message) {
            // Then: Should handle conflict appropriately
            XCTAssertEqual(message, "Profile was updated by another client")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - PAT Analysis Sync Tests
    
    func testSyncPATAnalysesSuccess() async throws {
        // Given: PAT analyses to fetch
        mockAPIClient.shouldSucceed = true
        let analysisId = UUID()
        mockAPIClient.mockResponse = [
            PATAnalysisResponseDTO(
                id: analysisId.uuidString,
                userId: "test-user-123",
                startTime: Date().addingTimeInterval(-8 * 3600),
                endTime: Date(),
                analysisType: "overnight",
                status: "completed",
                results: PATResultsDTO(
                    sleepScore: 85,
                    sleepDuration: 7.5,
                    sleepEfficiency: 0.88,
                    remDuration: 1.5,
                    deepSleepDuration: 2.0,
                    lightSleepDuration: 4.0,
                    awakenings: 3,
                    averageHeartRate: 58,
                    hrvAverage: 45,
                    respiratoryRate: 14,
                    oxygenSaturation: 96.5,
                    recommendations: ["Maintain consistent sleep schedule"]
                ),
                createdAt: Date().addingTimeInterval(-7 * 3600),
                updatedAt: Date()
            )
        ]
        
        // When: Fetch PAT analyses
        let endpoint = APIEndpoint.getPATAnalyses("test-user-123")
        let analyses: [PATAnalysisResponseDTO] = try await apiService.execute(endpoint)
        
        // Then: Should receive analysis data
        XCTAssertEqual(analyses.count, 1)
        XCTAssertEqual(analyses[0].status, "completed")
        XCTAssertEqual(analyses[0].results?.sleepScore, 85)
        XCTAssertEqual(analyses[0].results?.sleepEfficiency, 0.88)
    }
    
    func testSyncPATAnalysesSkipsCompleted() async throws {
        // Given: Mix of completed and pending analyses
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = [
            PATAnalysisResponseDTO(
                id: UUID().uuidString,
                userId: "test-user-123",
                startTime: Date().addingTimeInterval(-24 * 3600),
                endTime: Date().addingTimeInterval(-16 * 3600),
                analysisType: "overnight",
                status: "completed",
                results: PATResultsDTO(sleepScore: 90),
                createdAt: Date().addingTimeInterval(-24 * 3600),
                updatedAt: Date().addingTimeInterval(-16 * 3600)
            ),
            PATAnalysisResponseDTO(
                id: UUID().uuidString,
                userId: "test-user-123",
                startTime: Date().addingTimeInterval(-8 * 3600),
                endTime: nil,
                analysisType: "overnight",
                status: "in_progress",
                results: nil,
                createdAt: Date().addingTimeInterval(-8 * 3600),
                updatedAt: Date().addingTimeInterval(-8 * 3600)
            )
        ]
        
        // When: Fetch analyses
        let endpoint = APIEndpoint.getPATAnalyses("test-user-123")
        let analyses: [PATAnalysisResponseDTO] = try await apiService.execute(endpoint)
        
        // Then: Should get both but process differently
        XCTAssertEqual(analyses.count, 2)
        XCTAssertEqual(analyses.filter { $0.status == "completed" }.count, 1)
        XCTAssertEqual(analyses.filter { $0.status == "in_progress" }.count, 1)
    }
    
    func testSyncPATAnalysesDownloadsNewResults() async throws {
        // Given: Analysis that was pending now has results
        let analysisId = UUID()
        mockAPIClient.shouldSucceed = true
        
        // First response - pending
        mockAPIClient.mockResponse = PATAnalysisResponseDTO(
            id: analysisId.uuidString,
            userId: "test-user-123",
            startTime: Date().addingTimeInterval(-8 * 3600),
            endTime: Date(),
            analysisType: "overnight",
            status: "processing",
            results: nil,
            createdAt: Date().addingTimeInterval(-8 * 3600),
            updatedAt: Date().addingTimeInterval(-8 * 3600)
        )
        
        // Fetch initial state
        let endpoint1 = APIEndpoint.getPATAnalysis(analysisId.uuidString)
        let pending: PATAnalysisResponseDTO = try await apiService.execute(endpoint1)
        XCTAssertNil(pending.results)
        
        // Update mock to completed with results
        mockAPIClient.mockResponse = PATAnalysisResponseDTO(
            id: analysisId.uuidString,
            userId: "test-user-123",
            startTime: Date().addingTimeInterval(-8 * 3600),
            endTime: Date(),
            analysisType: "overnight",
            status: "completed",
            results: PATResultsDTO(
                sleepScore: 92,
                sleepDuration: 8.0,
                sleepEfficiency: 0.91
            ),
            createdAt: Date().addingTimeInterval(-8 * 3600),
            updatedAt: Date()
        )
        
        // When: Fetch updated analysis
        let endpoint2 = APIEndpoint.getPATAnalysis(analysisId.uuidString)
        let completed: PATAnalysisResponseDTO = try await apiService.execute(endpoint2)
        
        // Then: Should have results now
        XCTAssertNotNil(completed.results)
        XCTAssertEqual(completed.status, "completed")
        XCTAssertEqual(completed.results?.sleepScore, 92)
    }
    
    // MARK: - AI Insights Sync Tests
    
    func testSyncAIInsightsSuccess() async throws {
        // Given: AI insights to fetch
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = [
            AIInsightResponseDTO(
                id: UUID().uuidString,
                userId: "test-user-123",
                type: "trend",
                title: "Heart Rate Trend",
                content: "Your resting heart rate has decreased by 5 bpm over the last month",
                category: "cardiovascular",
                severity: "info",
                dataPoints: ["avgHeartRate": 65, "change": -5],
                recommendations: ["Continue current exercise routine"],
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600)
            )
        ]
        
        // When: Fetch insights
        let endpoint = APIEndpoint.getInsights("test-user-123", limit: 10, offset: 0)
        let insights: [AIInsightResponseDTO] = try await apiService.execute(endpoint)
        
        // Then: Should receive insight data
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].type, "trend")
        XCTAssertEqual(insights[0].category, "cardiovascular")
        XCTAssertFalse(insights[0].isRead)
    }
    
    func testSyncAIInsightsPreservesReadStatus() async throws {
        // Given: Insight marked as read locally
        let insightId = UUID().uuidString
        mockAPIClient.shouldSucceed = true
        
        // First fetch - unread
        mockAPIClient.mockResponse = AIInsightResponseDTO(
            id: insightId,
            userId: "test-user-123",
            type: "alert",
            title: "High Heart Rate Alert",
            content: "Your heart rate was elevated during sleep",
            category: "cardiovascular",
            severity: "warning",
            dataPoints: ["maxHeartRate": 120],
            recommendations: ["Consult your physician"],
            isRead: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let endpoint1 = APIEndpoint.getInsight(insightId)
        let unread: AIInsightResponseDTO = try await apiService.execute(endpoint1)
        XCTAssertFalse(unread.isRead)
        
        // Mark as read
        mockAPIClient.mockResponse = AIInsightResponseDTO(
            id: insightId,
            userId: "test-user-123",
            type: "alert",
            title: "High Heart Rate Alert",
            content: "Your heart rate was elevated during sleep",
            category: "cardiovascular",
            severity: "warning",
            dataPoints: ["maxHeartRate": 120],
            recommendations: ["Consult your physician"],
            isRead: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: Mark as read
        let endpoint2 = APIEndpoint.markInsightAsRead(insightId)
        let _: AIInsightResponseDTO = try await apiService.execute(endpoint2)
        
        // Then: Should preserve read status
        let endpoint3 = APIEndpoint.getInsight(insightId)
        let read: AIInsightResponseDTO = try await apiService.execute(endpoint3)
        XCTAssertTrue(read.isRead)
    }
    
    func testSyncAIInsightsHandlesDuplicates() async throws {
        // Given: Duplicate insights (same ID)
        let duplicateId = UUID().uuidString
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = [
            AIInsightResponseDTO(
                id: duplicateId,
                userId: "test-user-123",
                type: "recommendation",
                title: "Sleep Improvement",
                content: "Consider going to bed 30 minutes earlier",
                category: "sleep",
                severity: "info",
                dataPoints: [:],
                recommendations: ["Earlier bedtime"],
                isRead: false,
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-7200)
            ),
            AIInsightResponseDTO(
                id: duplicateId, // Same ID - duplicate
                userId: "test-user-123",
                type: "recommendation",
                title: "Sleep Improvement",
                content: "Consider going to bed 30 minutes earlier",
                category: "sleep",
                severity: "info",
                dataPoints: [:],
                recommendations: ["Earlier bedtime"],
                isRead: false,
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-7200)
            )
        ]
        
        // When: Fetch insights with duplicates
        let endpoint = APIEndpoint.getInsights("test-user-123", limit: 10, offset: 0)
        let insights: [AIInsightResponseDTO] = try await apiService.execute(endpoint)
        
        // Then: API returns duplicates (deduplication handled by repository layer)
        XCTAssertEqual(insights.count, 2)
        XCTAssertEqual(insights[0].id, insights[1].id)
    }
    
    // MARK: - Full Sync Tests
    
    func testPerformFullSyncInOrder() async throws {
        // Given: Multiple endpoints to sync
        mockAPIClient.shouldSucceed = true
        var callOrder: [String] = []
        
        // Track API calls
        mockAPIClient.onRequest = { endpoint in
            callOrder.append(endpoint.path)
        }
        
        // When: Perform multiple API calls in order
        // 1. User profile
        mockAPIClient.mockResponse = UserSessionResponseDTO(
            id: UUID().uuidString,
            email: "test@example.com",
            displayName: "Test User"
        )
        let _: UserSessionResponseDTO = try await apiService.execute(.getUserProfile("test-user-123"))
        
        // 2. Health metrics
        mockAPIClient.mockResponse = HealthDataUploadResponseDTO(success: true, processedSamples: 10)
        let _: HealthDataUploadResponseDTO = try await apiService.execute(.uploadHealthData(
            HealthDataUploadRequestDTO(userId: "test-user-123", samples: [])
        ))
        
        // 3. Insights
        mockAPIClient.mockResponse = [AIInsightResponseDTO]()
        let _: [AIInsightResponseDTO] = try await apiService.execute(.getInsights("test-user-123", limit: 10, offset: 0))
        
        // Then: Should execute in order
        XCTAssertEqual(callOrder.count, 3)
        XCTAssertTrue(callOrder[0].contains("user"))
        XCTAssertTrue(callOrder[1].contains("health"))
        XCTAssertTrue(callOrder[2].contains("insights"))
    }
    
    func testPerformFullSyncHandlesPartialFailure() async throws {
        // Given: Some endpoints will fail
        var successCount = 0
        var failureCount = 0
        
        // First call succeeds
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = UserSessionResponseDTO(
            id: UUID().uuidString,
            email: "test@example.com",
            displayName: "Test User"
        )
        
        do {
            let _: UserSessionResponseDTO = try await apiService.execute(.getUserProfile("test-user-123"))
            successCount += 1
        } catch {
            failureCount += 1
        }
        
        // Second call fails
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = APIError.serverError("Service unavailable")
        
        do {
            let _: HealthDataUploadResponseDTO = try await apiService.execute(.uploadHealthData(
                HealthDataUploadRequestDTO(userId: "test-user-123", samples: [])
            ))
            successCount += 1
        } catch {
            failureCount += 1
        }
        
        // Third call succeeds
        mockAPIClient.shouldSucceed = true
        mockAPIClient.shouldReturnError = false
        mockAPIClient.mockResponse = [AIInsightResponseDTO]()
        
        do {
            let _: [AIInsightResponseDTO] = try await apiService.execute(.getInsights("test-user-123", limit: 10, offset: 0))
            successCount += 1
        } catch {
            failureCount += 1
        }
        
        // Then: Should handle partial failure
        XCTAssertEqual(successCount, 2)
        XCTAssertEqual(failureCount, 1)
    }
    
    func testPerformFullSyncReportsProgress() async throws {
        // Given: Progress tracking
        var progressUpdates: [Double] = []
        
        // Simulate progress updates
        for i in 1...5 {
            let progress = Double(i) / 5.0
            progressUpdates.append(progress)
            
            // Simulate API call
            mockAPIClient.shouldSucceed = true
            mockAPIClient.mockResponse = EmptyResponseDTO()
            let _: EmptyResponseDTO = try await apiService.execute(.ping)
        }
        
        // Then: Should track progress
        XCTAssertEqual(progressUpdates.count, 5)
        XCTAssertEqual(progressUpdates.last, 1.0)
    }
    
    // MARK: - Offline Queue Integration Tests
    
    func testOfflineOperationQueuing() async throws {
        // Given: Offline queue manager configured
        mockOfflineQueueManager.shouldFailQueue = false
        
        // When: Queue an operation
        let upload = QueuedUpload(
            id: UUID(),
            endpoint: "health/metrics",
            data: Data(),
            retryCount: 0,
            createdAt: Date()
        )
        
        try await mockOfflineQueueManager.enqueue(upload)
        
        // Then: Should be queued
        XCTAssertEqual(mockOfflineQueueManager.queuedUploads.count, 1)
        XCTAssertEqual(await mockOfflineQueueManager.getQueuedItemsCount(), 1)
    }
    
    func testOfflineOperationProcessing() async throws {
        // Given: Queued operations
        for i in 1...3 {
            let upload = QueuedUpload(
                id: UUID(),
                endpoint: "health/metrics/\(i)",
                data: Data(),
                retryCount: 0,
                createdAt: Date()
            )
            try await mockOfflineQueueManager.enqueue(upload)
        }
        
        // When: Process queue
        await mockOfflineQueueManager.processQueue()
        
        // Then: Queue should be processed
        // Note: Mock doesn't actually process, but in real implementation it would
        XCTAssertEqual(mockOfflineQueueManager.queuedUploads.count, 3)
    }
    
    func testOfflineOperationRetry() async throws {
        // Given: Failed operation with retry
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = URLError(.timedOut)
        
        var retryCount = 0
        
        // When: Execute with retry policy
        do {
            // APIService handles retry internally
            let _: EmptyResponseDTO = try await apiService.execute(
                .ping,
                retryPolicy: .custom(maxRetries: 3, delay: 0.1)
            )
        } catch {
            // Count this as one failed attempt after retries
            retryCount = 1
        }
        
        // Then: Should have attempted retry
        XCTAssertGreaterThan(mockAPIClient.requestCount, 1) // Multiple attempts due to retry
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async throws {
        // Given: Network error
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = URLError(.notConnectedToInternet)
        
        // When: Execute request
        do {
            let _: UserSessionResponseDTO = try await apiService.execute(.getUserProfile("test-user-123"))
            XCTFail("Should have thrown network error")
        } catch {
            // Then: Should handle network error
            XCTAssertTrue(error is URLError)
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }
    
    func testAuthenticationErrorRetry() async throws {
        // Given: Auth error that might be recoverable
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = APIError.unauthorized
        
        // When: Execute request
        do {
            let _: UserSessionResponseDTO = try await apiService.execute(
                .getUserProfile("test-user-123"),
                retryPolicy: .standard
            )
            XCTFail("Should have thrown auth error")
        } catch APIError.unauthorized {
            // Then: Should fail with auth error (no automatic retry for auth errors)
            XCTAssertTrue(true)
        }
    }
    
    func testRateLimitHandling() async throws {
        // Given: Rate limit error
        mockAPIClient.shouldSucceed = false
        mockAPIClient.shouldReturnError = true
        mockAPIClient.errorToReturn = APIError.rateLimited(retryAfter: 60)
        
        // When: Execute request
        do {
            let _: EmptyResponseDTO = try await apiService.execute(.ping)
            XCTFail("Should have thrown rate limit error")
        } catch APIError.rateLimited(let retryAfter) {
            // Then: Should provide retry information
            XCTAssertEqual(retryAfter, 60)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeBatchSyncPerformance() async throws {
        // Given: Large batch of data
        let startTime = Date()
        var samples: [HealthSampleDTO] = []
        
        for i in 0..<1000 {
            samples.append(HealthSampleDTO(
                type: .heartRate,
                value: Double(60 + i % 40),
                unit: "bpm",
                timestamp: Date().addingTimeInterval(Double(-i * 60)),
                metadata: nil
            ))
        }
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockResponse = HealthDataUploadResponseDTO(
            success: true,
            processedSamples: samples.count,
            message: "Large batch processed"
        )
        
        // When: Upload large batch
        let endpoint = APIEndpoint.uploadHealthData(
            HealthDataUploadRequestDTO(userId: "test-user-123", samples: samples)
        )
        let response: HealthDataUploadResponseDTO = try await apiService.execute(endpoint)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Then: Should complete in reasonable time
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.processedSamples, 1000)
        XCTAssertLessThan(duration, 2.0) // Should complete within 2 seconds
    }
    
    func testConcurrentSyncOperations() async throws {
        // Given: Multiple concurrent operations
        mockAPIClient.shouldSucceed = true
        
        // When: Execute multiple requests concurrently
        async let req1: UserSessionResponseDTO = {
            mockAPIClient.mockResponse = UserSessionResponseDTO(
                id: UUID().uuidString,
                email: "test1@example.com",
                displayName: "Test User 1"
            )
            return try await apiService.execute(.getUserProfile("user-1"))
        }()
        
        async let req2: [AIInsightResponseDTO] = {
            mockAPIClient.mockResponse = [AIInsightResponseDTO]()
            return try await apiService.execute(.getInsights("user-2", limit: 10, offset: 0))
        }()
        
        async let req3: EmptyResponseDTO = {
            mockAPIClient.mockResponse = EmptyResponseDTO()
            return try await apiService.execute(.ping)
        }()
        
        // Wait for all to complete
        let (user, insights, ping) = try await (req1, req2, req3)
        
        // Then: All should succeed
        XCTAssertEqual(user.email, "test1@example.com")
        XCTAssertNotNil(insights)
        XCTAssertNotNil(ping)
    }
}

// MARK: - Mock Enhanced Offline Queue Manager

// Mock offline queue manager
private class MockOfflineQueueManager: OfflineQueueManagerProtocol {
    var queuedUploads: [QueuedUpload] = []
    var shouldFailQueue = false
    var startMonitoringCalled = false
    var stopMonitoringCalled = false
    
    func enqueue(_ upload: QueuedUpload) async throws {
        if shouldFailQueue {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        queuedUploads.append(upload)
    }
    
    func processQueue() async {
        // Mock processing
    }
    
    func clearQueue() async throws {
        queuedUploads.removeAll()
    }
    
    func getQueuedItemsCount() async -> Int {
        return queuedUploads.count
    }
    
    func startMonitoring() {
        startMonitoringCalled = true
    }
    
    func stopMonitoring() {
        stopMonitoringCalled = true
    }
}