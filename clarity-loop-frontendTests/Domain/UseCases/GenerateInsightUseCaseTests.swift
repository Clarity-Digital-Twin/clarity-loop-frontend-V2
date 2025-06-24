@testable import clarity_loop_frontend
import XCTest

final class GenerateInsightUseCaseTests: XCTestCase {
    var generateInsightUseCase: GenerateInsightUseCase!
    var mockInsightAIService: MockInsightAIService!
    var mockHealthDataRepository: MockHealthDataRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockInsightAIService = MockInsightAIService()
        mockHealthDataRepository = MockHealthDataRepository()
        generateInsightUseCase = GenerateInsightUseCase(
            insightAIService: mockInsightAIService,
            healthDataRepository: mockHealthDataRepository
        )
    }

    override func tearDownWithError() throws {
        generateInsightUseCase = nil
        mockInsightAIService = nil
        mockHealthDataRepository = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testExecute_Success() async throws {
        // Given
        mockHealthDataRepository.shouldSucceed = true
        mockInsightAIService.shouldSucceed = true

        // When
        let insight = try await generateInsightUseCase.execute()

        // Then
        XCTAssertNotNil(insight)
    }

    func testExecute_Failure() async throws {
        // Given: Health data repository fails
        mockHealthDataRepository.shouldSucceed = false

        // When / Then: Should throw error from health data repository
        do {
            _ = try await generateInsightUseCase.execute()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error, "Should have error when health data fetch fails")
            
            // Verify it's the expected error type
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let statusCode, let message):
                    XCTAssertEqual(statusCode, 500, "Should be server error")
                    XCTAssertEqual(message, "Database error", "Should have correct error message")
                default:
                    XCTFail("Wrong error type: \(apiError)")
                }
            }
        }
    }

    func testExecute_InsufficientData() async throws {
        // Given: Health data repository returns empty data
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = [] // Empty data
        mockInsightAIService.shouldSucceed = true

        // When: Execute with insufficient data
        let insight = try await generateInsightUseCase.execute()

        // Then: Should still return an insight (AI service handles empty data gracefully)
        XCTAssertNotNil(insight, "Should still return an insight even with no data")
        XCTAssertEqual(insight.narrative, "Test narrative", "Should have generated narrative")
        XCTAssertEqual(insight.confidenceScore, 0.9, "Should have confidence score")
        XCTAssertEqual(insight.userId, "test", "Should have user ID")
    }
    
    // MARK: - Additional Tests
    
    func testExecute_DailySummaryType() async throws {
        // Given: Health data with various metrics
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = [
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "steps",
                timestamp: Date(),
                metadata: nil,
                activityData: ActivityDataDTO(steps: 10000, distance: 8.5, floorsClimbed: 15, activeCalories: 350, exerciseMinutes: 45),
                biometricData: nil,
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            ),
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "heart_rate",
                timestamp: Date(),
                metadata: nil,
                activityData: nil,
                biometricData: BiometricDataDTO(heartRate: 72, heartRateVariability: 45, bloodPressureSystolic: nil, bloodPressureDiastolic: nil, respiratoryRate: nil, oxygenSaturation: nil, bodyTemperature: nil),
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            )
        ]
        mockInsightAIService.shouldSucceed = true
        
        // When: Execute daily summary
        let insight = try await generateInsightUseCase.execute(type: .dailySummary, context: "Test context")
        
        // Then: Verify insight generation
        XCTAssertNotNil(insight, "Should generate daily summary insight")
        XCTAssertEqual(insight.userId, "test", "Should have correct user ID")
        XCTAssertEqual(insight.narrative, "Test narrative", "Should have generated narrative")
    }
    
    func testExecute_ChatResponseType() async throws {
        // Given: Health data and chat context
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = [
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "steps",
                timestamp: Date(),
                metadata: nil,
                activityData: ActivityDataDTO(steps: 5000, distance: 4.2, floorsClimbed: 10, activeCalories: 200, exerciseMinutes: 20),
                biometricData: nil,
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            )
        ]
        mockInsightAIService.shouldSucceed = true
        
        // Create chat message history
        let chatHistory = [
            ChatMessage(role: .user, content: "How are my steps today?"),
            ChatMessage(role: .assistant, content: "You've taken 5000 steps so far.")
        ]
        
        // When: Execute chat response
        let insight = try await generateInsightUseCase.execute(
            type: .chatResponse(userMessage: "Should I walk more?", conversationHistory: chatHistory)
        )
        
        // Then: Verify chat response
        XCTAssertNotNil(insight, "Should generate chat response")
        XCTAssertEqual(insight.userId, "test", "Should have correct user ID")
    }
    
    func testExecute_CustomAnalysisType() async throws {
        // Given: Health data and custom analysis
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = []
        mockInsightAIService.shouldSucceed = true
        
        let customAnalysis: [String: Any] = [
            "trend": "improving",
            "averageSteps": 8500,
            "recommendation": "increase by 10%"
        ]
        
        // When: Execute custom analysis
        let insight = try await generateInsightUseCase.execute(
            type: .custom(analysisResults: customAnalysis),
            context: "Weekly fitness analysis"
        )
        
        // Then: Verify custom insight
        XCTAssertNotNil(insight, "Should generate custom insight")
        XCTAssertEqual(insight.confidenceScore, 0.9, "Should have high confidence")
    }
    
    func testExecute_AIServiceFailure() async throws {
        // Given: Health data succeeds but AI service fails
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = [
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "steps",
                timestamp: Date(),
                metadata: nil,
                activityData: ActivityDataDTO(steps: 1000, distance: 0.8, floorsClimbed: 2, activeCalories: 50, exerciseMinutes: 10),
                biometricData: nil,
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            )
        ]
        mockInsightAIService.shouldSucceed = false
        
        // When/Then: Should throw AI service error
        do {
            _ = try await generateInsightUseCase.execute()
            XCTFail("Should have thrown AI service error")
        } catch {
            XCTAssertNotNil(error, "Should have error when AI service fails")
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let statusCode, let message):
                    XCTAssertEqual(statusCode, 500, "Should be server error")
                    XCTAssertEqual(message, "AI service error", "Should have AI error message")
                default:
                    XCTFail("Wrong error type")
                }
            }
        }
    }
    
    func testBuildHealthContext_WithCompleteData() async throws {
        // Given: Complete health data with all metric types
        mockHealthDataRepository.shouldSucceed = true
        mockHealthDataRepository.mockHealthData = [
            // Steps data
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "steps",
                timestamp: Date(),
                metadata: nil,
                activityData: ActivityDataDTO(steps: 12000, distance: 10.5, floorsClimbed: 20, activeCalories: 400, exerciseMinutes: 60),
                biometricData: nil,
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            ),
            // Heart rate data
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "heart_rate",
                timestamp: Date(),
                metadata: nil,
                activityData: nil,
                biometricData: BiometricDataDTO(heartRate: 68, heartRateVariability: 50, bloodPressureSystolic: nil, bloodPressureDiastolic: nil, respiratoryRate: nil, oxygenSaturation: nil, bodyTemperature: nil),
                sleepData: nil,
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            ),
            // Sleep data
            HealthMetricDTO(
                id: UUID(),
                userId: "test",
                metricType: "sleep",
                timestamp: Date(),
                metadata: nil,
                activityData: nil,
                biometricData: nil,
                sleepData: SleepDataDTO(
                    totalTimeInBed: 28800,
                    totalTimeAsleep: 25200,
                    sleepEfficiency: 0.875,
                    sleepStages: nil,
                    timeToFallAsleep: nil,
                    numberOfAwakenings: nil
                ),
                nutritionData: nil,
                source: "healthkit",
                deviceInfo: nil
            )
        ]
        mockInsightAIService.shouldSucceed = true
        
        // When: Execute to trigger context building
        let insight = try await generateInsightUseCase.execute()
        
        // Then: Verify insight is generated with complete data context
        XCTAssertNotNil(insight, "Should generate insight with complete health context")
        // The actual context building is internal, but we verify the use case executes successfully
    }
}

class MockInsightAIService: InsightAIServiceProtocol {
    var shouldSucceed = true

    func generateInsight(
        from analysisResults: [String: Any],
        context: String?,
        insightType: String,
        includeRecommendations: Bool,
        language: String
    ) async throws -> HealthInsightDTO {
        if shouldSucceed {
            return HealthInsightDTO(
                userId: "test",
                narrative: "Test narrative",
                keyInsights: [],
                recommendations: [],
                confidenceScore: 0.9,
                generatedAt: Date()
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "AI service error")
        }
    }

    func generateInsightFromHealthData(
        metrics: [HealthMetricDTO],
        patAnalysis: [String: Any]?,
        customContext: String?
    ) async throws -> HealthInsightDTO {
        if shouldSucceed {
            return HealthInsightDTO(
                userId: "test",
                narrative: "Test narrative",
                keyInsights: [],
                recommendations: [],
                confidenceScore: 0.9,
                generatedAt: Date()
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "AI service error")
        }
    }

    func generateChatResponse(
        userMessage: String,
        conversationHistory: [ChatMessage],
        healthContext: [String: Any]?
    ) async throws -> HealthInsightDTO {
        if shouldSucceed {
            return HealthInsightDTO(
                userId: "test",
                narrative: "Test narrative",
                keyInsights: [],
                recommendations: [],
                confidenceScore: 0.9,
                generatedAt: Date()
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "AI service error")
        }
    }

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        if shouldSucceed {
            let data = InsightHistoryDataDTO(insights: [], totalCount: 0, hasMore: false, pagination: nil)
            return InsightHistoryResponseDTO(success: true, data: data, metadata: nil)
        } else {
            throw APIError.serverError(statusCode: 500, message: "History error")
        }
    }

    func checkServiceStatus() async throws -> ServiceStatusResponseDTO {
        if shouldSucceed {
            let modelInfo = ModelInfoDTO(modelName: "test", projectId: "test", initialized: true, capabilities: [])
            let data = ServiceStatusDataDTO(
                service: "test",
                status: "ok",
                modelInfo: modelInfo,
                timestamp: Date(),
                uptime: nil,
                version: nil
            )
            return ServiceStatusResponseDTO(success: true, data: data, metadata: nil)
        } else {
            throw APIError.serverError(statusCode: 500, message: "Status error")
        }
    }
}

class MockHealthDataRepository: HealthDataRepositoryProtocol {
    var shouldSucceed = true
    var mockHealthData: [HealthMetricDTO] = []

    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        if shouldSucceed {
            return PaginatedMetricsResponseDTO(data: mockHealthData)
        } else {
            throw APIError.serverError(statusCode: 500, message: "Database error")
        }
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        if shouldSucceed {
            HealthKitUploadResponseDTO(
                success: true,
                uploadId: "mock-upload-id",
                processedSamples: 10,
                skippedSamples: 0,
                errors: nil,
                message: "Mock upload successful"
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "Upload error")
        }
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        if shouldSucceed {
            HealthKitSyncResponseDTO(
                success: true,
                syncId: "mock-sync-id",
                status: "completed",
                estimatedDuration: 30.0,
                message: "Mock sync successful"
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "Sync error")
        }
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        if shouldSucceed {
            HealthKitSyncStatusDTO(
                syncId: syncId,
                status: "completed",
                progress: 1.0,
                processedSamples: 25,
                totalSamples: 25,
                errors: nil,
                completedAt: Date()
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "Sync status error")
        }
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        if shouldSucceed {
            HealthKitUploadStatusDTO(
                uploadId: uploadId,
                status: "completed",
                progress: 1.0,
                processedSamples: 15,
                totalSamples: 15,
                errors: nil,
                completedAt: Date(),
                message: "Upload completed successfully"
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "Upload status error")
        }
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        if shouldSucceed {
            HealthDataProcessingStatusDTO(
                processingId: id,
                status: "completed",
                progress: 1.0,
                processedMetrics: 30,
                totalMetrics: 30,
                estimatedTimeRemaining: nil,
                completedAt: Date(),
                errors: nil,
                message: "Processing completed successfully"
            )
        } else {
            throw APIError.serverError(statusCode: 500, message: "Processing status error")
        }
    }
}
