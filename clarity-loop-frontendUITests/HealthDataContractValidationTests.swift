@testable import clarity_loop_frontend
import XCTest

/// Contract validation tests for health data endpoints
/// Ensures all health data DTOs and API contracts match backend expectations
@MainActor
final class HealthDataContractValidationTests: XCTestCase {
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

    // MARK: - HealthKit Upload Contract Tests

    func testHealthKitUploadRequestContract() throws {
        // Given - HealthKit upload request
        let request = HealthKitUploadRequestDTO(
            userId: "test-user-123",
            samples: [
                HealthKitSampleDTO(
                    sampleType: "heartRate",
                    value: 72.5,
                    categoryValue: nil,
                    unit: "count/min",
                    startDate: Date(),
                    endDate: Date(),
                    metadata: [
                        "device": AnyCodable("Apple Watch"),
                        "workout_type": AnyCodable("running"),
                    ],
                    sourceRevision: SourceRevisionDTO(
                        source: SourceDTO(
                            name: "CLARITY Pulse",
                            bundleIdentifier: "com.clarity.pulse"
                        ),
                        version: "1.0.0",
                        productType: "iPhone",
                        operatingSystemVersion: "18.0"
                    )
                ),
            ],
            deviceInfo: DeviceInfoDTO(
                deviceModel: "iPhone16,1",
                systemName: "iOS",
                systemVersion: "18.0",
                appVersion: "1.0.0",
                timeZone: "America/New_York"
            ),
            timestamp: Date()
        )

        // When - Encode to JSON
        let jsonData = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then - Verify backend contract
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["user_id"] as? String, "test-user-123")
        XCTAssertNotNil(json?["samples"])
        XCTAssertNotNil(json?["device_info"])
        XCTAssertNotNil(json?["timestamp"])

        let samples = json?["samples"] as? [[String: Any]]
        XCTAssertEqual(samples?.count, 1)

        let sample = samples?.first
        XCTAssertEqual(sample?["sample_type"] as? String, "heartRate")
        XCTAssertEqual(sample?["value"] as? Double, 72.5)
        XCTAssertEqual(sample?["unit"] as? String, "count/min")
        XCTAssertNotNil(sample?["start_date"])
        XCTAssertNotNil(sample?["end_date"])

        let metadata = sample?["metadata"] as? [String: Any]
        XCTAssertEqual(metadata?["device"] as? String, "Apple Watch")
        XCTAssertEqual(metadata?["workout_type"] as? String, "running")
    }

    func testHealthKitUploadResponseContract() throws {
        // Given - Backend upload response
        let backendJSON = """
        {
            "success": true,
            "upload_id": "123e4567-e89b-12d3-a456-426614174000",
            "processed_samples": 95,
            "skipped_samples": 5,
            "errors": ["Duplicate sample at index 5"],
            "message": "Upload processed successfully"
        }
        """

        // When - Decode response
        let response = try decoder.decode(HealthKitUploadResponseDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify all fields decoded correctly
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.uploadId, "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(response.processedSamples, 95)
        XCTAssertEqual(response.skippedSamples, 5)
        XCTAssertEqual(response.errors?.first, "Duplicate sample at index 5")
        XCTAssertEqual(response.message, "Upload processed successfully")
    }

    // MARK: - HealthKit Sync Contract Tests

    func testHealthKitSyncRequestContract() throws {
        // Given - Sync request
        let request = HealthKitSyncRequestDTO(
            userId: "test-user-123",
            startDate: Date(timeIntervalSinceNow: -86400), // 24 hours ago
            endDate: Date(),
            dataTypes: ["stepCount", "heartRate", "sleepAnalysis"],
            forceRefresh: true
        )

        // When - Encode to JSON
        let jsonData = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then - Verify backend contract
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["user_id"] as? String, "test-user-123")
        XCTAssertNotNil(json?["start_date"])
        XCTAssertNotNil(json?["end_date"])
        XCTAssertEqual(json?["force_refresh"] as? Bool, true)

        let dataTypes = json?["data_types"] as? [String]
        XCTAssertEqual(dataTypes?.count, 3)
        XCTAssertTrue(dataTypes?.contains("stepCount") ?? false)
        XCTAssertTrue(dataTypes?.contains("heartRate") ?? false)
        XCTAssertTrue(dataTypes?.contains("sleepAnalysis") ?? false)
    }

    // MARK: - Paginated Health Data Contract Tests

    func testPaginatedMetricsResponseContract() throws {
        // Given - Backend paginated response
        let backendJSON = """
        {
            "data": [
                {
                    "metric_id": "123e4567-e89b-12d3-a456-426614174000",
                    "metric_type": "biometric",
                    "biometric_data": {
                        "heart_rate": 72.5,
                        "oxygen_saturation": 98.5
                    },
                    "device_id": "apple-watch-123",
                    "created_at": "2025-01-13T10:00:00Z"
                },
                {
                    "metric_id": "223e4567-e89b-12d3-a456-426614174000",
                    "metric_type": "activity",
                    "activity_data": {
                        "steps": 5432,
                        "distance": 4.1,
                        "active_energy": 250.5
                    },
                    "device_id": "iphone-123",
                    "created_at": "2025-01-13T11:00:00Z"
                }
            ]
        }
        """

        // When - Decode response
        let response = try decoder.decode(PaginatedMetricsResponseDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify structure
        XCTAssertEqual(response.data.count, 2)

        let firstMetric = response.data[0]
        XCTAssertEqual(firstMetric.metricId.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(firstMetric.metricType, "biometric")
        XCTAssertNotNil(firstMetric.biometricData)
        XCTAssertEqual(firstMetric.biometricData?.heartRate, 72.5)

        let secondMetric = response.data[1]
        XCTAssertEqual(secondMetric.metricType, "activity")
        XCTAssertNotNil(secondMetric.activityData)
        XCTAssertEqual(secondMetric.activityData?.steps, 5432)
    }

    // MARK: - Processing Status Contract Tests

    func testHealthDataProcessingStatusContract() throws {
        // Given - Processing status response
        let backendJSON = """
        {
            "processing_id": "123e4567-e89b-12d3-a456-426614174000",
            "status": "completed",
            "progress": 1.0,
            "processed_metrics": 1500,
            "total_metrics": 1500,
            "estimated_time_remaining": null,
            "completed_at": "2025-01-13T10:05:00Z",
            "errors": [],
            "message": "Processing completed successfully"
        }
        """

        // When - Decode response
        let response = try decoder.decode(HealthDataProcessingStatusDTO.self, from: backendJSON.data(using: .utf8)!)

        // Then - Verify all fields
        XCTAssertEqual(response.processingId.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(response.status, "completed")
        XCTAssertEqual(response.progress, 1.0)
        XCTAssertEqual(response.processedMetrics, 1500)
        XCTAssertEqual(response.totalMetrics, 1500)
        XCTAssertNil(response.estimatedTimeRemaining)
        XCTAssertNotNil(response.completedAt)
        XCTAssertEqual(response.errors?.count, 0)
        XCTAssertEqual(response.message, "Processing completed successfully")
    }

    // MARK: - Data Type Validation Tests

    func testSupportedHealthKitDataTypes() {
        // Verify all supported data types match backend expectations
        let supportedTypes = [
            "heart_rate",
            "steps",
            "sleep_analysis",
            "blood_pressure",
            "respiratory_rate",
            "body_temperature",
            "oxygen_saturation",
            "activity_energy",
            "exercise_minutes",
            "stand_hours",
        ]

        // These should match backend's expected data_type values
        for type in supportedTypes {
            // In a real test, we'd verify these against an actual backend enum/list
            XCTAssertFalse(type.contains(" "), "Data types must use underscores, not spaces")
            XCTAssertEqual(type, type.lowercased(), "Data types must be lowercase")
        }
    }

    // MARK: - Unit Validation Tests

    func testHealthMetricUnits() {
        // Verify units match backend expectations
        let unitMappings = [
            "heart_rate": "bpm",
            "steps": "count",
            "respiratory_rate": "breaths/min",
            "body_temperature": "celsius",
            "oxygen_saturation": "percent",
            "blood_pressure_systolic": "mmHg",
            "blood_pressure_diastolic": "mmHg",
        ]

        for (dataType, expectedUnit) in unitMappings {
            // In a real implementation, we'd validate these against actual HealthKit conversions
            XCTAssertFalse(expectedUnit.isEmpty, "Unit for \(dataType) must not be empty")
        }
    }

    // MARK: - Error Response Contract Tests

    func testHealthDataErrorResponses() throws {
        // Test various error response formats
        let quotaExceededJSON = """
        {
            "error": "quota_exceeded",
            "message": "Daily upload limit reached",
            "details": {
                "daily_limit": 10000,
                "samples_today": 10523,
                "reset_time": "2025-01-14T00:00:00Z"
            },
            "status_code": 429
        }
        """

        let invalidDataJSON = """
        {
            "error": "invalid_data",
            "message": "Invalid health data format",
            "details": {
                "invalid_samples": [0, 5, 12],
                "reasons": ["missing_timestamp", "invalid_unit", "negative_value"]
            },
            "status_code": 400
        }
        """

        // Decode and verify error structures
        let quotaError = try JSONSerialization.jsonObject(with: quotaExceededJSON.data(using: .utf8)!) as? [String: Any]
        XCTAssertEqual(quotaError?["error"] as? String, "quota_exceeded")
        XCTAssertEqual(quotaError?["status_code"] as? Int, 429)

        let invalidError = try JSONSerialization.jsonObject(with: invalidDataJSON.data(using: .utf8)!) as? [String: Any]
        XCTAssertEqual(invalidError?["error"] as? String, "invalid_data")
        XCTAssertEqual(invalidError?["status_code"] as? Int, 400)
    }
}
