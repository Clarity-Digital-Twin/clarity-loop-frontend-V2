@testable import clarity_loop_frontend
import XCTest

final class InsightAIServiceTests: XCTestCase {
    // MARK: - Properties
    
    var insightAIService: InsightAIService!
    var mockAPIClient: MockAPIClient!

    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPIClient = MockAPIClient()
        insightAIService = InsightAIService(apiClient: mockAPIClient)
    }

    override func tearDownWithError() throws {
        insightAIService = nil
        mockAPIClient = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testGenerateInsights_Success() async throws {
        // Given: Configure mock for successful response
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockInsightGeneration = InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user-123",
                narrative: "Your heart rate shows excellent cardiovascular fitness with an average of 65 bpm.",
                keyInsights: [
                    "Resting heart rate is optimal",
                    "Recovery time after exercise is improving",
                    "Heart rate variability indicates good stress management"
                ],
                recommendations: [
                    "Continue your current exercise routine",
                    "Consider adding more interval training",
                    "Maintain consistent sleep schedule"
                ],
                confidenceScore: 0.92,
                generatedAt: Date()
            ),
            metadata: ResponseMetadataDTO(
                requestId: "test-request-123",
                timestamp: Date(),
                version: "1.0"
            )
        )
        
        // When: Generate insights
        let analysisResults: [String: Any] = [
            "avg_heart_rate": 65,
            "max_heart_rate": 120,
            "min_heart_rate": 55,
            "daily_steps": 10000
        ]
        
        let insight = try await insightAIService.generateInsight(
            from: analysisResults,
            context: "Focus on cardiovascular health",
            insightType: "daily_summary",
            includeRecommendations: true,
            language: "en"
        )
        
        // Then: Verify the response
        XCTAssertEqual(insight.userId, "test-user-123")
        XCTAssertTrue(insight.narrative.contains("heart rate"))
        XCTAssertEqual(insight.keyInsights.count, 3)
        XCTAssertEqual(insight.recommendations.count, 3)
        XCTAssertEqual(insight.confidenceScore, 0.92)
        
        // Verify API was called correctly
        XCTAssertTrue(mockAPIClient.generateInsightCalled)
        XCTAssertNotNil(mockAPIClient.capturedInsightRequest)
        XCTAssertEqual(mockAPIClient.capturedInsightRequest?.insightType, "daily_summary")
        XCTAssertTrue(mockAPIClient.capturedInsightRequest?.includeRecommendations ?? false)
    }

    func testGenerateInsights_EmptyData() async throws {
        // Given: Configure mock for empty data response
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockInsightGeneration = InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user-123",
                narrative: "No health data available for analysis. Please sync your health data to receive personalized insights.",
                keyInsights: [],
                recommendations: ["Connect your health tracking device", "Enable health data permissions"],
                confidenceScore: 0.0,
                generatedAt: Date()
            ),
            metadata: nil
        )
        
        // When: Generate insights with empty data
        let emptyAnalysisResults: [String: Any] = [:]
        
        let insight = try await insightAIService.generateInsight(
            from: emptyAnalysisResults,
            context: "User has no health data",
            insightType: "daily_summary"
        )
        
        // Then: Verify empty data handling
        XCTAssertTrue(insight.narrative.contains("No health data"))
        XCTAssertEqual(insight.keyInsights.count, 0)
        XCTAssertGreaterThan(insight.recommendations.count, 0)
        XCTAssertEqual(insight.confidenceScore, 0.0)
    }

    func testGenerateInsights_InvalidData() async throws {
        // Given: Configure mock to simulate invalid data error
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.invalidRequest("Invalid data format")
        
        // When/Then: Attempt to generate insights with invalid data should throw
        let invalidData: [String: Any] = [
            "invalid_metric": "not_a_number",
            "corrupt_data": NSNull()
        ]
        
        do {
            _ = try await insightAIService.generateInsight(
                from: invalidData,
                context: "Invalid data test"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify error is properly propagated
            XCTAssertTrue(error is APIError)
            if let apiError = error as? APIError {
                switch apiError {
                case .invalidRequest(let message):
                    XCTAssertTrue(message.contains("Invalid"))
                default:
                    XCTFail("Expected invalidRequest error")
                }
            }
        }
    }

    func testGenerateInsights_APIError() async throws {
        // Given: Configure mock to simulate API error
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.networkError(URLError(.notConnectedToInternet))
        
        // When/Then: API error should be properly handled
        do {
            _ = try await insightAIService.generateInsight(
                from: ["test": "data"],
                context: "Test context"
            )
            XCTFail("Expected network error to be thrown")
        } catch {
            // Verify network error is propagated
            XCTAssertTrue(error is APIError)
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError:
                    // Expected error type
                    break
                default:
                    XCTFail("Expected network error but got: \(apiError)")
                }
            }
        }
        
        // Verify API was attempted
        XCTAssertTrue(mockAPIClient.generateInsightCalled)
    }

    func testGenerateInsights_RateLimit() async throws {
        // Given: Configure mock to simulate rate limiting
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.rateLimited(retryAfter: 60)
        
        // When/Then: Rate limit error should be handled
        do {
            _ = try await insightAIService.generateInsight(
                from: ["metric": "value"],
                context: "Rate limit test"
            )
            XCTFail("Expected rate limit error")
        } catch {
            // Verify rate limit error
            XCTAssertTrue(error is APIError)
            if let apiError = error as? APIError {
                switch apiError {
                case .rateLimited(let retryAfter):
                    XCTAssertEqual(retryAfter, 60)
                default:
                    XCTFail("Expected rate limited error")
                }
            }
        }
    }
    
    // MARK: - Additional Tests
    
    func testGenerateInsightFromHealthData() async throws {
        // Given: Health metrics data
        let metrics = [
            HealthMetricDTO(
                id: UUID(),
                userId: "test-user",
                metricType: "steps",
                timestamp: Date(),
                metadata: nil,
                activityData: ActivityDataDTO(
                    steps: 8500,
                    distance: 6.5,
                    floorsClimbed: 10,
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
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockInsightGeneration = InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user",
                narrative: "Great activity today! You've taken 8,500 steps and your heart rate is healthy.",
                keyInsights: ["Active lifestyle", "Healthy heart rate"],
                recommendations: ["Keep up the good work"],
                confidenceScore: 0.88,
                generatedAt: Date()
            ),
            metadata: nil
        )
        
        // When: Generate insight from health data
        let insight = try await insightAIService.generateInsightFromHealthData(
            metrics: metrics,
            patAnalysis: nil,
            customContext: "Daily health summary"
        )
        
        // Then: Verify insight generation
        XCTAssertTrue(insight.narrative.contains("steps"))
        XCTAssertEqual(insight.keyInsights.count, 2)
        XCTAssertEqual(insight.confidenceScore, 0.88)
        
        // Verify the request was properly formatted
        XCTAssertNotNil(mockAPIClient.capturedInsightRequest)
        let analysisResults = mockAPIClient.capturedInsightRequest?.analysisResults
        XCTAssertNotNil(analysisResults?["daily_steps"])
        XCTAssertNotNil(analysisResults?["avg_heart_rate"])
    }
    
    func testCheckServiceStatus() async throws {
        // Given: Service is healthy
        mockAPIClient.shouldSucceed = true
        
        // When: Check service status
        let status = try await insightAIService.checkServiceStatus()
        
        // Then: Verify healthy status
        XCTAssertEqual(status.status, "healthy")
        XCTAssertEqual(status.service, "insights")
        XCTAssertNotNil(status.version)
        XCTAssertNotNil(status.dependencies)
        XCTAssertGreaterThan(status.dependencies?.count ?? 0, 0)
        
        // Verify metrics if available
        if let metrics = status.metrics {
            XCTAssertGreaterThan(metrics.uptime ?? 0, 0.9)
            XCTAssertLessThan(metrics.errorRate ?? 1.0, 0.1)
        }
    }
    
    func testGenerateChatResponse() async throws {
        // Given: Chat conversation setup
        let conversationHistory = [
            ChatMessage(sender: .user, text: "How is my heart health?"),
            ChatMessage(sender: .assistant, text: "Your heart health looks good based on recent data.")
        ]
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockInsightGeneration = InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user",
                narrative: "Your heart rate has been stable at an average of 70 bpm over the past week.",
                keyInsights: [],
                recommendations: [],
                confidenceScore: 0.85,
                generatedAt: Date()
            ),
            metadata: nil
        )
        
        // When: Generate chat response
        let response = try await insightAIService.generateChatResponse(
            userMessage: "What about my resting heart rate?",
            conversationHistory: conversationHistory,
            healthContext: ["avg_heart_rate": 70]
        )
        
        // Then: Verify response
        XCTAssertTrue(response.narrative.contains("heart rate"))
        XCTAssertEqual(response.confidenceScore, 0.85)
        
        // Verify request formatting
        XCTAssertNotNil(mockAPIClient.capturedInsightRequest)
        XCTAssertEqual(mockAPIClient.capturedInsightRequest?.insightType, "chat_response")
        XCTAssertFalse(mockAPIClient.capturedInsightRequest?.includeRecommendations ?? true)
    }
}
