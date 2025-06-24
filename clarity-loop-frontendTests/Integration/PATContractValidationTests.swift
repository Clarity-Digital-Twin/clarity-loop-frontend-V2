@testable import clarity_loop_frontend
import XCTest

/// Contract validation tests for PAT (Physical Activity Tracking) analysis endpoints
/// Ensures all PAT analysis DTOs and API contracts match backend expectations
@MainActor
final class PATContractValidationTests: XCTestCase {
    private var encoder: JSONEncoder!
    private var decoder: JSONDecoder!

    override func setUp() async throws {
        try await super.setUp()

        // Configure encoder to match backend expectations
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        // Configure decoder to match backend responses
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Step Data Analysis Contract Tests

    func testStepDataRequestContract() throws {
        // Given - Step data analysis request
        let request = StepDataRequestDTO(
            userId: "test-user-123",
            stepData: [
                StepDataPointDTO(
                    timestamp: Date(),
                    stepCount: 523,
                    source: "Apple Watch"
                ),
            ],
            analysisType: "circadian_rhythm",
            timeRange: TimeRangeDTO(
                startDate: Date(timeIntervalSinceNow: -86400),
                endDate: Date()
            )
        )

        // When - Encode to JSON
        let jsonData = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then - Verify backend contract
        XCTAssertNotNil(json?["step_data"])
        XCTAssertEqual(json?["user_id"] as? String, "test-user-123")
        XCTAssertEqual(json?["analysis_type"] as? String, "circadian_rhythm")

        // Verify step data structure
        let stepData = json?["step_data"] as? [[String: Any]]
        XCTAssertEqual(stepData?.count, 1)

        let firstStep = stepData?.first
        XCTAssertNotNil(firstStep?["timestamp"])
        XCTAssertEqual(firstStep?["step_count"] as? Int, 523)
        XCTAssertEqual(firstStep?["source"] as? String, "Apple Watch")

        // Verify time range
        let timeRange = json?["time_range"] as? [String: Any]
        XCTAssertNotNil(timeRange?["start_date"])
        XCTAssertNotNil(timeRange?["end_date"])
    }

    func testStepAnalysisResponseContract() throws {
        // Given - Backend step analysis response
        let backendJSON = """
        {
            "success": true,
            "data": {
                "daily_step_pattern": {
                    "average_steps_per_day": 8543.5,
                    "peak_activity_hours": [9, 14, 18],
                    "consistency_score": 0.85,
                    "trends_over_time": ["increasing", "stable"]
                },
                "activity_insights": {
                    "activity_level": "moderate",
                    "goal_progress": 0.78,
                    "improvement_areas": ["evening_activity", "weekend_consistency"],
                    "strengths": ["morning_routine", "weekday_consistency"]
                },
                "health_metrics": {
                    "estimated_calories_burned": 2456.8,
                    "active_minutes_per_day": 45.5,
                    "sedentary_time_percentage": 0.62
                },
                "recommendations": [
                    "Consider evening walks to boost daily step count",
                    "Maintain your excellent morning routine"
                ]
            },
            "analysis_id": "123e4567-e89b-12d3-a456-426614174000",
            "status": "completed",
            "message": null,
            "estimated_completion_time": null,
            "created_at": "2025-01-13T10:00:00Z"
        }
        """

        // When - Decode response
        let response = try decoder.decode(StepAnalysisResponseDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify all fields
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.analysisId, "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(response.status, "completed")

        // Verify step analysis data
        let stepData = response.data
        XCTAssertNotNil(stepData)

        // Verify daily pattern
        XCTAssertEqual(stepData?.dailyStepPattern.averageStepsPerDay, 8543.5)
        XCTAssertEqual(stepData?.dailyStepPattern.consistencyScore, 0.85)
        XCTAssertEqual(stepData?.dailyStepPattern.peakActivityHours, [9, 14, 18])

        // Verify activity insights
        XCTAssertEqual(stepData?.activityInsights.activityLevel, "moderate")
        XCTAssertEqual(stepData?.activityInsights.goalProgress, 0.78)

        // Verify health metrics
        XCTAssertEqual(stepData?.healthMetrics.estimatedCaloriesBurned, 2456.8)
        XCTAssertEqual(stepData?.healthMetrics.activeMinutesPerDay, 45.5)

        // Verify recommendations
        XCTAssertEqual(stepData?.recommendations.count, 2)
    }

    // MARK: - Actigraphy Analysis Contract Tests

    func testActigraphyRequestContract() throws {
        // Given - Direct actigraphy analysis request
        let request = DirectActigraphyRequestDTO(
            userId: "test-user-123",
            actigraphyData: [
                ActigraphyDataPointDTO(
                    timestamp: Date(),
                    activityLevel: 1.12,
                    lightExposure: 250.5,
                    temperature: 36.5,
                    heartRate: 72.0
                ),
            ],
            analysisType: "sleep_staging",
            timeRange: TimeRangeDTO(
                startDate: Date(timeIntervalSinceNow: -86400),
                endDate: Date()
            )
        )

        // When - Encode to JSON
        let jsonData = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then - Verify backend contract
        XCTAssertNotNil(json?["actigraphy_data"])
        XCTAssertEqual(json?["user_id"] as? String, "test-user-123")
        XCTAssertEqual(json?["analysis_type"] as? String, "sleep_staging")

        // Verify actigraphy data structure
        let actigraphyData = json?["actigraphy_data"] as? [[String: Any]]
        XCTAssertEqual(actigraphyData?.count, 1)

        let dataPoint = actigraphyData?.first
        XCTAssertNotNil(dataPoint?["timestamp"])
        XCTAssertEqual(dataPoint?["activity_level"] as? Double, 1.12)
        XCTAssertEqual(dataPoint?["light_exposure"] as? Double, 250.5)
        XCTAssertEqual(dataPoint?["temperature"] as? Double, 36.5)
        XCTAssertEqual(dataPoint?["heart_rate"] as? Double, 72.0)

        // Verify time range
        let timeRange = json?["time_range"] as? [String: Any]
        XCTAssertNotNil(timeRange?["start_date"])
        XCTAssertNotNil(timeRange?["end_date"])
    }

    func testActigraphyAnalysisResponseContract() throws {
        // Given - Backend actigraphy analysis response
        let backendJSON = """
        {
            "success": true,
            "data": {
                "sleep_metrics": {
                    "total_sleep_time": 495,
                    "sleep_efficiency": 0.87,
                    "sleep_latency": 15,
                    "wake_after_sleep_onset": 45,
                    "number_of_awakenings": 12,
                    "sleep_stages": ["light", "deep", "rem", "wake"]
                },
                "activity_patterns": {
                    "daily_activity_score": 7.8,
                    "peak_activity_time": "14:30",
                    "rest_periods": [
                        {
                            "start_time": "2025-01-12T22:30:00Z",
                            "end_time": "2025-01-13T06:45:00Z",
                            "rest_quality": 0.85
                        }
                    ],
                    "activity_variability": 0.45
                },
                "circadian_rhythm": {
                    "phase": -0.5,
                    "amplitude": 0.82,
                    "stability": 0.78,
                    "regularity": 0.91,
                    "recommendations": [
                        "Maintain consistent bedtime",
                        "Increase morning light exposure"
                    ]
                },
                "recommendations": [
                    "Your sleep pattern shows good consistency",
                    "Consider reducing screen time before bed"
                ]
            },
            "analysis_id": "789e0123-e89b-12d3-a456-426614174000",
            "status": "completed",
            "message": null,
            "estimated_completion_time": null,
            "created_at": "2025-01-13T10:00:00Z"
        }
        """

        // When - Decode response
        let response = try decoder.decode(ActigraphyAnalysisResponseDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify all fields
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.analysisId, "789e0123-e89b-12d3-a456-426614174000")
        XCTAssertEqual(response.status, "completed")

        // Verify actigraphy analysis data
        let analysisData = response.data
        XCTAssertNotNil(analysisData)

        // Verify sleep metrics
        XCTAssertEqual(analysisData?.sleepMetrics.totalSleepTime, 495)
        XCTAssertEqual(analysisData?.sleepMetrics.sleepEfficiency, 0.87)
        XCTAssertEqual(analysisData?.sleepMetrics.numberOfAwakenings, 12)

        // Verify activity patterns
        XCTAssertEqual(analysisData?.activityPatterns.dailyActivityScore, 7.8)
        XCTAssertEqual(analysisData?.activityPatterns.peakActivityTime, "14:30")

        // Verify circadian rhythm
        XCTAssertEqual(analysisData?.circadianRhythm.phase, -0.5)
        XCTAssertEqual(analysisData?.circadianRhythm.stability, 0.78)

        // Verify recommendations
        XCTAssertEqual(analysisData?.recommendations.count, 2)
    }

    // MARK: - PAT Analysis Response Contract Tests

    func testPATAnalysisResponseContract() throws {
        // Given - PAT analysis response (generic format)
        let backendJSON = """
        {
            "id": "pat-analysis-123",
            "status": "completed",
            "pat_features": {
                "interdaily_stability": 0.78,
                "intradaily_variability": 0.45,
                "relative_amplitude": 0.82
            },
            "analysis": {
                "sleep_stages": ["light", "deep", "rem"],
                "clinical_insights": [
                    "Normal circadian rhythm detected",
                    "Good sleep-wake cycle consistency"
                ],
                "confidence_score": 0.92,
                "sleep_efficiency": 0.87,
                "total_sleep_time": 495,
                "wake_after_sleep_onset": 45,
                "sleep_latency": 15
            },
            "error_message": null,
            "created_at": "2025-01-13T09:00:00Z",
            "completed_at": "2025-01-13T09:05:00Z"
        }
        """

        // When - Decode response
        let response = try decoder.decode(PATAnalysisResponseDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify all fields
        XCTAssertEqual(response.id, "pat-analysis-123")
        XCTAssertEqual(response.status, "completed")
        XCTAssertNil(response.errorMessage)

        // Verify PAT features
        XCTAssertEqual(response.patFeatures?["interdaily_stability"], 0.78)
        XCTAssertEqual(response.patFeatures?["relative_amplitude"], 0.82)

        // Verify analysis data
        let analysis = response.analysis
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis?.sleepStages?.count, 3)
        XCTAssertEqual(analysis?.confidenceScore, 0.92)
        XCTAssertEqual(analysis?.sleepEfficiency, 0.87)
        XCTAssertEqual(analysis?.totalSleepTime, 495)
    }

    // MARK: - Date Format Tests

    func testPATDateFormatting() throws {
        // Verify all date fields use ISO8601 with snake_case
        let dataPoint = StepDataPointDTO(
            timestamp: ISO8601DateFormatter().date(from: "2025-01-13T10:30:45Z")!,
            stepCount: 100,
            source: "test"
        )

        let jsonData = try encoder.encode(dataPoint)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Verify ISO8601 format and snake_case
        XCTAssertTrue(jsonString.contains("2025-01-13T10:30:45Z"))
        XCTAssertTrue(jsonString.contains("\"timestamp\""))
        XCTAssertTrue(jsonString.contains("\"step_count\""))
        XCTAssertFalse(jsonString.contains("\"stepCount\""))
    }

    // MARK: - Error Response Tests

    func testPATErrorResponseContract() throws {
        // Test PAT-specific error responses
        let errorJSON = """
        {
            "id": "pat-analysis-failed-123",
            "status": "failed",
            "pat_features": null,
            "analysis": null,
            "error_message": "Insufficient data for analysis: minimum 24 hours required",
            "created_at": "2025-01-13T09:00:00Z",
            "completed_at": "2025-01-13T09:01:00Z"
        }
        """

        // When - Decode error response
        let response = try decoder.decode(PATAnalysisResponseDTO.self, from: errorJSON.data(using: .utf8)!)

        // Then - Verify error structure
        XCTAssertEqual(response.status, "failed")
        XCTAssertNil(response.patFeatures)
        XCTAssertNil(response.analysis)
        XCTAssertEqual(response.errorMessage, "Insufficient data for analysis: minimum 24 hours required")
        XCTAssertNotNil(response.completedAt)
    }
}
