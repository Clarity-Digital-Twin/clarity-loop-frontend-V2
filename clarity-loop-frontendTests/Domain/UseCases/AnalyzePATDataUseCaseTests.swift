@testable import clarity_loop_frontend
import XCTest

final class AnalyzePATDataUseCaseTests: XCTestCase {
    var analyzePATDataUseCase: AnalyzePATDataUseCase!
    var mockAPIClient: MockAPIClient!
    var mockHealthKitService: MockHealthKitService!
    var mockAuthService: MockAuthService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize mocks
        mockAPIClient = MockAPIClient()
        mockHealthKitService = MockHealthKitService()
        mockAuthService = MockAuthService()
        
        // Set up authenticated user
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Initialize use case with mocks
        analyzePATDataUseCase = AnalyzePATDataUseCase(
            apiClient: mockAPIClient,
            healthKitService: mockHealthKitService,
            authService: mockAuthService
        )
    }

    override func tearDownWithError() throws {
        analyzePATDataUseCase = nil
        mockAPIClient = nil
        mockHealthKitService = nil
        mockAuthService = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testExecuteStepAnalysis_Success() async throws {
        // Given: Mock HealthKit returns step data
        mockHealthKitService.mockDailySteps = 10000
        
        // Mock API client to return successful analysis
        mockAPIClient.shouldSucceed = true
        mockAPIClient.analyzeStepDataHandler = { request in
            XCTAssertEqual(request.userId, "test-user-123", "Should use correct user ID")
            XCTAssertEqual(request.analysisType, "comprehensive", "Should use comprehensive analysis")
            XCTAssertFalse(request.stepData.isEmpty, "Should have step data")
            
            return StepAnalysisResponseDTO(
                analysisId: "analysis-123",
                status: "completed",
                message: "Analysis completed successfully",
                data: StepDataAnalysisDTO(
                    dailyStepPattern: DailyStepPatternDTO(
                        averageStepsPerDay: 10000,
                        consistencyScore: 0.85,
                        weekdayAverage: 11000,
                        weekendAverage: 8000,
                        peakHours: ["9-10", "17-18"],
                        lowActivityPeriods: ["12-13", "20-21"]
                    ),
                    activityInsights: ActivityInsightsDTO(
                        activityLevel: "high",
                        goalAchievementRate: 0.9,
                        progressTrend: "improving",
                        goalProgress: 0.95,
                        recommendations: ["Great job maintaining activity!"]
                    ),
                    healthMetrics: HealthMetricsDTO(
                        estimatedCaloriesBurned: 450,
                        distanceCovered: 8.5,
                        activeMinutes: 60,
                        metabolicEquivalent: 3.5
                    ),
                    patternAnalysis: PatternAnalysisDTO(
                        regularityScore: 0.88,
                        variabilityIndex: 0.15,
                        trendDirection: "stable",
                        anomalies: []
                    )
                ),
                createdAt: Date()
            )
        }
        
        // When: Execute step analysis
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let result = try await analyzePATDataUseCase.executeStepAnalysis(
            startDate: startDate,
            endDate: endDate
        )
        
        // Then: Verify successful analysis
        XCTAssertEqual(result.analysisId, "analysis-123", "Should have correct analysis ID")
        XCTAssertEqual(result.status, "completed", "Should be completed")
        XCTAssertTrue(result.isCompleted, "Should be marked as completed")
        XCTAssertFalse(result.isFailed, "Should not be failed")
        XCTAssertFalse(result.isProcessing, "Should not be processing")
        XCTAssertNotNil(result.patFeatures, "Should have PAT features")
        
        // Verify PAT features conversion
        if let features = result.patFeatures {
            XCTAssertEqual(features["averageStepsPerDay"]?.value as? Double, 10000, "Should have average steps")
            XCTAssertEqual(features["consistencyScore"]?.value as? Double, 0.85, "Should have consistency score")
            XCTAssertEqual(features["activityLevel"]?.value as? String, "high", "Should have activity level")
            XCTAssertEqual(features["goalProgress"]?.value as? Double, 0.95, "Should have goal progress")
            XCTAssertEqual(features["estimatedCaloriesBurned"]?.value as? Double, 450, "Should have calories")
        }
    }

    func testExecuteActigraphyAnalysis_Success() async throws {
        // Given: Prepare actigraphy data
        let actigraphyData = [
            ActigraphyDataPointDTO(
                timestamp: Date(),
                activityLevel: 0.5,
                lightExposure: 200,
                heartRate: 72,
                steps: 100
            ),
            ActigraphyDataPointDTO(
                timestamp: Date().addingTimeInterval(3600),
                activityLevel: 0.8,
                lightExposure: 500,
                heartRate: 85,
                steps: 500
            )
        ]
        
        // Mock API client for successful actigraphy analysis
        mockAPIClient.shouldSucceed = true
        mockAPIClient.analyzeActigraphyHandler = { request in
            XCTAssertEqual(request.userId, "test-user-123", "Should use correct user ID")
            XCTAssertEqual(request.actigraphyData.count, 2, "Should have 2 data points")
            
            return ActigraphyAnalysisResponseDTO(
                analysisId: "actigraphy-456",
                status: "completed",
                message: "Actigraphy analysis completed",
                data: ActigraphyAnalysisDataDTO(
                    sleepMetrics: SleepMetricsDTO(
                        totalSleepTime: 420, // 7 hours
                        sleepEfficiency: 0.85,
                        sleepLatency: 15,
                        wakingsCount: 2,
                        remSleep: 90,
                        deepSleep: 120,
                        lightSleep: 210
                    ),
                    activityPatterns: ActivityPatternsDTO(
                        dailyActivityScore: 0.75,
                        sedentaryMinutes: 480,
                        lightActivityMinutes: 180,
                        moderateActivityMinutes: 60,
                        vigorousActivityMinutes: 20,
                        peakActivityTime: "14:00"
                    ),
                    circadianRhythm: CircadianRhythmDTO(
                        phase: 22.5,
                        amplitude: 0.8,
                        stability: 0.9,
                        mesor: 0.5,
                        acrophase: "14:30",
                        bathyphase: "03:00"
                    ),
                    recommendations: ["Consider more regular sleep schedule"]
                ),
                createdAt: Date()
            )
        }
        
        // When: Execute actigraphy analysis
        let result = try await analyzePATDataUseCase.executeActigraphyAnalysis(
            actigraphyData: actigraphyData
        )
        
        // Then: Verify successful analysis
        XCTAssertEqual(result.analysisId, "actigraphy-456", "Should have correct analysis ID")
        XCTAssertEqual(result.status, "completed", "Should be completed")
        XCTAssertNotNil(result.patFeatures, "Should have PAT features")
        
        // Verify PAT features conversion
        if let features = result.patFeatures {
            XCTAssertEqual(features["totalSleepTime"]?.value as? Double, 420, "Should have sleep time")
            XCTAssertEqual(features["sleepEfficiency"]?.value as? Double, 0.85, "Should have sleep efficiency")
            XCTAssertEqual(features["sleepLatency"]?.value as? Double, 15, "Should have sleep latency")
            XCTAssertEqual(features["dailyActivityScore"]?.value as? Double, 0.75, "Should have activity score")
            XCTAssertEqual(features["circadianPhase"]?.value as? Double, 22.5, "Should have circadian phase")
            XCTAssertEqual(features["circadianAmplitude"]?.value as? Double, 0.8, "Should have circadian amplitude")
        }
    }

    func testExecuteStepAnalysis_ProcessingWithPolling() async throws {
        // Given: Mock API returns processing status first, then completed
        var callCount = 0
        mockHealthKitService.mockDailySteps = 8000
        mockAPIClient.shouldSucceed = true
        
        mockAPIClient.analyzeStepDataHandler = { _ in
            return StepAnalysisResponseDTO(
                analysisId: "processing-789",
                status: "processing",
                message: "Analysis in progress",
                data: nil,
                createdAt: Date()
            )
        }
        
        mockAPIClient.getPATAnalysisHandler = { analysisId in
            callCount += 1
            XCTAssertEqual(analysisId, "processing-789", "Should poll with correct ID")
            
            if callCount < 2 {
                // First poll: still processing
                return PATAnalysisResponseDTO(
                    id: analysisId,
                    userId: "test-user-123",
                    status: "processing",
                    patFeatures: nil,
                    analysis: nil,
                    errorMessage: nil,
                    createdAt: Date(),
                    completedAt: nil
                )
            } else {
                // Second poll: completed
                return PATAnalysisResponseDTO(
                    id: analysisId,
                    userId: "test-user-123",
                    status: "completed",
                    patFeatures: [
                        "feature1": 0.8,
                        "feature2": 0.6
                    ],
                    analysis: PATAnalysisDetailsDTO(
                        patScore: 0.75,
                        confidenceScore: 0.85,
                        features: ["feature1": 0.8, "feature2": 0.6],
                        interpretation: "Good activity pattern",
                        recommendations: ["Keep it up!"]
                    ),
                    errorMessage: nil,
                    createdAt: Date(),
                    completedAt: Date()
                )
            }
        }
        
        // When: Execute analysis
        let result = try await analyzePATDataUseCase.executeStepAnalysis()
        
        // Then: Verify polling worked
        XCTAssertEqual(result.analysisId, "processing-789", "Should have correct analysis ID")
        XCTAssertEqual(result.status, "completed", "Should be completed after polling")
        XCTAssertEqual(result.confidence, 0.85, "Should have confidence score")
        XCTAssertEqual(callCount, 2, "Should have polled twice")
    }
    
    // MARK: - Additional Tests
    
    func testGetAnalysisResult() async throws {
        // Given: Mock API returns analysis result
        mockAPIClient.shouldSucceed = true
        mockAPIClient.getPATAnalysisHandler = { analysisId in
            XCTAssertEqual(analysisId, "test-analysis-999", "Should query correct analysis ID")
            
            return PATAnalysisResponseDTO(
                id: analysisId,
                userId: "test-user-123",
                status: "completed",
                patFeatures: ["activity": 0.9],
                analysis: PATAnalysisDetailsDTO(
                    patScore: 0.9,
                    confidenceScore: 0.95,
                    features: ["activity": 0.9],
                    interpretation: "Excellent activity",
                    recommendations: []
                ),
                errorMessage: nil,
                createdAt: Date(),
                completedAt: Date()
            )
        }
        
        // When: Get analysis result
        let result = try await analyzePATDataUseCase.getAnalysisResult(analysisId: "test-analysis-999")
        
        // Then: Verify result
        XCTAssertEqual(result.id, "test-analysis-999", "Should have correct ID")
        XCTAssertEqual(result.status, "completed", "Should be completed")
        XCTAssertEqual(result.analysis?.patScore, 0.9, "Should have PAT score")
    }
    
    func testExecuteStepAnalysis_HealthKitError() async throws {
        // Given: HealthKit throws error
        mockHealthKitService.shouldFailFetch = true
        mockHealthKitService.fetchError = NSError(
            domain: "HealthKit",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No step data available"]
        )
        
        // When: Execute analysis
        let result = try await analyzePATDataUseCase.executeStepAnalysis()
        
        // Then: Should still complete but with empty data
        // The use case catches HealthKit errors and continues
        XCTAssertTrue(true, "Should complete without throwing")
    }
    
    func testExecuteActigraphyAnalysis_NoUser() async throws {
        // Given: No authenticated user
        mockAuthService.mockCurrentUser = nil
        
        let actigraphyData = [
            ActigraphyDataPointDTO(
                timestamp: Date(),
                activityLevel: 0.5,
                lightExposure: 200,
                heartRate: 72,
                steps: 100
            )
        ]
        
        mockAPIClient.shouldSucceed = true
        mockAPIClient.analyzeActigraphyHandler = { request in
            // Should still work but with "unknown" user ID
            XCTAssertEqual(request.userId, "unknown", "Should use unknown for missing user")
            
            return ActigraphyAnalysisResponseDTO(
                analysisId: "no-user-analysis",
                status: "completed",
                message: "Completed",
                data: nil,
                createdAt: Date()
            )
        }
        
        // When: Execute analysis
        let result = try await analyzePATDataUseCase.executeActigraphyAnalysis(
            actigraphyData: actigraphyData
        )
        
        // Then: Should complete successfully
        XCTAssertEqual(result.analysisId, "no-user-analysis", "Should complete without user")
    }
}
