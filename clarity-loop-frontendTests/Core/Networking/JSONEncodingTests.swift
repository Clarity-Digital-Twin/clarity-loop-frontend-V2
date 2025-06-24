@testable import clarity_loop_frontend
import XCTest

final class JSONEncodingTests: XCTestCase {
    var encoder: JSONEncoder!
    var decoder: JSONDecoder!

    override func setUp() async throws {
        try await super.setUp()

        // Match the configuration in APIClient
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func testInsightGenerationRequestEncoding() throws {
        // Given
        let request = InsightGenerationRequestDTO(
            analysisResults: ["test_key": AnyCodable("test_value")],
            context: "Test context",
            insightType: "comprehensive",
            includeRecommendations: true,
            language: "en"
        )

        // When
        let jsonData = try encoder.encode(request)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Then
        XCTAssertTrue(jsonString.contains("\"analysis_results\""))
        XCTAssertTrue(jsonString.contains("\"insight_type\""))
        XCTAssertTrue(jsonString.contains("\"include_recommendations\""))
        XCTAssertFalse(jsonString.contains("\"analysisResults\""))
        XCTAssertFalse(jsonString.contains("\"insightType\""))
        XCTAssertFalse(jsonString.contains("\"includeRecommendations\""))
    }

    func testHealthKitUploadRequestEncoding() throws {
        // Given
        let sourceRevision = SourceRevisionDTO(
            source: SourceDTO(name: "Apple Watch", bundleIdentifier: "com.apple.health"),
            version: "7.0",
            productType: "Watch6,1",
            operatingSystemVersion: "8.0"
        )

        let sample = HealthKitSampleDTO(
            sampleType: "heartRate",
            value: 72.5,
            categoryValue: nil,
            unit: "count/min",
            startDate: Date(),
            endDate: Date(),
            metadata: ["HKMetadataKeyHeartRateMotionContext": AnyCodable(1)],
            sourceRevision: sourceRevision
        )

        let deviceInfo = DeviceInfoDTO(
            deviceModel: "iPhone13,1",
            systemName: "iOS",
            systemVersion: "15.0",
            appVersion: "1.0.0",
            timeZone: "America/New_York"
        )

        let request = HealthKitUploadRequestDTO(
            userId: "user-123",
            samples: [sample],
            deviceInfo: deviceInfo,
            timestamp: Date()
        )

        // When
        let jsonData = try encoder.encode(request)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Then
        XCTAssertTrue(jsonString.contains("\"user_id\""))
        XCTAssertTrue(jsonString.contains("\"samples\""))
        XCTAssertTrue(jsonString.contains("\"device_info\""))
        XCTAssertTrue(jsonString.contains("\"timestamp\""))
        XCTAssertTrue(jsonString.contains("\"sample_type\""))
        XCTAssertTrue(jsonString.contains("\"start_date\""))
        XCTAssertTrue(jsonString.contains("\"end_date\""))
        XCTAssertTrue(jsonString.contains("\"source_revision\""))
    }

    func testInsightGenerationResponseDecoding() throws {
        // Given
        let jsonString = """
        {
            "success": true,
            "data": {
                "user_id": "test-user",
                "narrative": "Test narrative",
                "key_insights": ["Insight 1", "Insight 2"],
                "recommendations": ["Rec 1", "Rec 2"],
                "confidence_score": 0.85,
                "generated_at": "2025-06-08T12:00:00Z"
            },
            "metadata": null
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // When
        let response = try decoder.decode(InsightGenerationResponseDTO.self, from: jsonData)

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data.userId, "test-user")
        XCTAssertEqual(response.data.narrative, "Test narrative")
        XCTAssertEqual(response.data.keyInsights.count, 2)
        XCTAssertEqual(response.data.recommendations.count, 2)
        XCTAssertEqual(response.data.confidenceScore, 0.85)
    }
}
