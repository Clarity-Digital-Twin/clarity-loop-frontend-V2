//
//  HealthMetricFlowIntegrationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Integration tests for health metric recording and retrieval flow
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

struct HealthMetricsListResponse: Codable {
    let data: [HealthMetricDTO]
    let total: Int
}

struct BatchHealthMetricsResponse: Codable {
    let metrics: [HealthMetricDTO]
    let created: Int
}

final class HealthMetricFlowIntegrationTests: BaseIntegrationTestCase {
    
    override func setUp() {
        super.setUp()
        setUpIntegration()
    }
    
    override func tearDown() {
        // Clean up happens in setUpIntegration for next test
        // This avoids concurrency issues with tearDown
        super.tearDown()
    }
    
    // MARK: - Health Metric Recording Flow
    
    func test_recordHealthMetric_completesFullFlow() async throws {
        // Given - prepare test data
        let userId = UUID()
        let expectedMetric = HealthMetric(
            id: UUID(),
            userId: userId,
            type: .heartRate,
            value: 75,
            unit: "bpm",
            recordedAt: Date()
        )
        
        let metricDTO = HealthMetricDTO(
            id: expectedMetric.id.uuidString,
            userId: expectedMetric.userId.uuidString,
            type: "heart_rate",
            value: expectedMetric.value,
            unit: expectedMetric.unit,
            recordedAt: ISO8601DateFormatter().string(from: expectedMetric.recordedAt),
            source: "manual",
            notes: nil
        )
        
        await givenNetworkResponse(
            for: "/api/v1/health-metrics",
            response: metricDTO
        )
        
        // When - record metric through use case
        let recordUseCase = testContainer.require(RecordHealthMetricUseCase.self)
        let recordedMetric = try await recordUseCase.execute(
            userId: userId,
            type: .heartRate,
            value: 75
        )
        
        // Then - verify complete flow
        XCTAssertEqual(recordedMetric.value, 75)
        XCTAssertEqual(recordedMetric.type, .heartRate)
        XCTAssertEqual(recordedMetric.unit, "bpm")
        
        // Verify network request
        await verifyNetworkRequest(to: "/api/v1/health-metrics", method: "POST")
        
        // Verify persistence
        let persistedMetrics = try await testPersistence.fetchAll() as [HealthMetric]
        XCTAssertEqual(persistedMetrics.count, 1)
        XCTAssertEqual(persistedMetrics.first?.value, 75)
    }
    
    func test_recordHealthMetric_withValidation_rejectsInvalidData() async throws {
        // Given - invalid heart rate
        let userId = UUID()
        
        // When/Then - should reject out of range value
        let recordUseCase = testContainer.require(RecordHealthMetricUseCase.self)
        
        do {
            _ = try await recordUseCase.execute(
                userId: userId,
                type: .heartRate,
                value: 300 // Too high for heart rate
            )
            XCTFail("Should reject invalid heart rate")
        } catch {
            if case ValidationError.outOfRange = error {
                // Success - correct validation error
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        // Verify no network request was made
        let capturedRequests = await testNetworkClient.capturedRequests
        XCTAssertTrue(capturedRequests.isEmpty)
    }
    
    func test_batchRecordHealthMetrics_processesMultipleMetrics() async throws {
        // Given - multiple metrics
        let userId = UUID()
        let metrics = [
            MetricData(type: .heartRate, value: 72),
            MetricData(type: .bloodPressureSystolic, value: 120),
            MetricData(type: .bloodPressureDiastolic, value: 80)
        ]
        
        let responseDTOs = metrics.enumerated().map { index, metric in
            HealthMetricDTO(
                id: UUID().uuidString,
                userId: userId.uuidString,
                type: metricTypeToString(metric.type),
                value: metric.value,
                unit: metric.type.defaultUnit,
                recordedAt: ISO8601DateFormatter().string(from: Date()),
                source: "manual",
                notes: nil
            )
        }
        
        await givenNetworkResponse(
            for: "/api/v1/health-metrics/batch",
            response: BatchHealthMetricsResponse(metrics: responseDTOs, created: 3)
        )
        
        // When - record batch
        let recordUseCase = testContainer.require(RecordHealthMetricUseCase.self)
        let recordedMetrics = try await recordUseCase.executeBatch(
            userId: userId,
            metrics: metrics
        )
        
        // Then - verify all metrics processed
        XCTAssertEqual(recordedMetrics.count, 3)
        XCTAssertEqual(recordedMetrics[0].type, .heartRate)
        XCTAssertEqual(recordedMetrics[1].type, .bloodPressureSystolic)
        XCTAssertEqual(recordedMetrics[2].type, .bloodPressureDiastolic)
        
        // Verify network request
        await verifyNetworkRequest(to: "/api/v1/health-metrics/batch", method: "POST")
        
        // Verify all persisted
        let persistedMetrics = try await testPersistence.fetchAll() as [HealthMetric]
        XCTAssertEqual(persistedMetrics.count, 3)
    }
    
    // MARK: - Health Metric Retrieval Flow
    
    func test_retrieveHealthMetrics_byDateRange_filtersCorrectly() async throws {
        // Given - set up metrics in different time ranges
        let userId = UUID()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-604800)
        
        let metricsData = [
            (date: now, value: 75.0),
            (date: yesterday, value: 72.0),
            (date: lastWeek, value: 70.0)
        ]
        
        let metricDTOs = metricsData.map { data in
            HealthMetricDTO(
                id: UUID().uuidString,
                userId: userId.uuidString,
                type: "heart_rate",
                value: data.value,
                unit: "bpm",
                recordedAt: ISO8601DateFormatter().string(from: data.date),
                source: "manual",
                notes: nil
            )
        }
        
        // Only return metrics from last 2 days
        let filteredDTOs = Array(metricDTOs.prefix(2))
        
        await givenNetworkResponse(
            for: "/api/v1/health-metrics",
            response: HealthMetricsListResponse(data: filteredDTOs, total: 2)
        )
        
        // When - retrieve with date range
        let repository = testContainer.require(HealthMetricRepositoryProtocol.self)
        let metrics = try await repository.findByUserIdAndDateRange(
            userId: userId,
            startDate: yesterday.addingTimeInterval(-3600), // 1 hour before yesterday
            endDate: now
        )
        
        // Then - verify filtering
        XCTAssertEqual(metrics.count, 2)
        XCTAssertTrue(metrics.allSatisfy { $0.recordedAt >= yesterday.addingTimeInterval(-3600) })
        
        // Verify correct API parameters were sent
        let requests = await testNetworkClient.capturedRequests
        let request = requests.first
        XCTAssertNotNil(request?.parameters?["start_date"])
        XCTAssertNotNil(request?.parameters?["end_date"])
    }
    
    // MARK: - Duplicate Detection
    
    func test_duplicateMetricDetection_preventsDoubleSubmission() async throws {
        // Given - existing metric
        let userId = UUID()
        let existingMetric = createTestHealthMetric(
            userId: userId,
            type: .heartRate,
            value: 72
        )
        
        // Pre-populate persistence
        try await testPersistence.save(existingMetric)
        
        // When - check for duplicate
        let recordUseCase = testContainer.require(RecordHealthMetricUseCase.self)
        let isDuplicate = try await recordUseCase.isDuplicateMetric(
            userId: userId,
            type: .heartRate,
            value: 72,
            withinMinutes: 5
        )
        
        // Then
        XCTAssertTrue(isDuplicate)
    }
    
    // MARK: - Helpers
    
    private func metricTypeToString(_ type: HealthMetricType) -> String {
        switch type {
        case .heartRate: return "heart_rate"
        case .bloodPressureSystolic: return "blood_pressure_systolic"
        case .bloodPressureDiastolic: return "blood_pressure_diastolic"
        case .bloodGlucose: return "blood_glucose"
        case .weight: return "weight"
        case .height: return "height"
        case .bodyTemperature: return "body_temperature"
        case .oxygenSaturation: return "oxygen_saturation"
        case .steps: return "steps"
        case .sleepDuration: return "sleep_duration"
        case .respiratoryRate: return "respiratory_rate"
        case .caloriesBurned: return "calories_burned"
        case .waterIntake: return "water_intake"
        case .exerciseDuration: return "exercise_duration"
        case .custom(let name): return name.lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }
}