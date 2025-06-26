//
//  HealthMetricRepositoryImplementationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for HealthMetricRepository implementation following TDD
//

import XCTest
@testable import ClarityData
@testable import ClarityDomain

final class HealthMetricRepositoryImplementationTests: XCTestCase {
    
    private var sut: HealthMetricRepositoryImplementation!
    private var mockAPIClient: MockAPIClient!
    private var mockPersistence: MockPersistenceService!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockPersistence = MockPersistenceService()
        sut = HealthMetricRepositoryImplementation(
            apiClient: mockAPIClient,
            persistence: mockPersistence
        )
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    
    func test_create_whenValid_shouldSaveAndReturn() async throws {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 72,
            unit: "BPM",
            recordedAt: Date()
        )
        
        let expectedDTO = HealthMetricDTO(
            id: metric.id.uuidString,
            userId: metric.userId.uuidString,
            type: "heart_rate",
            value: metric.value,
            unit: metric.unit,
            recordedAt: ISO8601DateFormatter().string(from: metric.recordedAt),
            source: metric.source?.rawValue,
            notes: metric.notes
        )
        
        mockAPIClient.mockResponse = expectedDTO
        
        // When
        let savedMetric = try await sut.create(metric)
        
        // Then
        XCTAssertEqual(savedMetric.id, metric.id)
        XCTAssertTrue(mockAPIClient.postCalled)
        XCTAssertEqual(mockPersistence.savedMetrics.count, 1)
    }
    
    // MARK: - Batch Create Tests
    
    func test_createBatch_shouldSaveAllMetrics() async throws {
        // Given
        let userId = UUID()
        let metrics = [
            HealthMetric(
                userId: userId,
                type: .heartRate,
                value: 72,
                unit: "BPM",
                recordedAt: Date()
            ),
            HealthMetric(
                userId: userId,
                type: .steps,
                value: 10000,
                unit: "steps",
                recordedAt: Date()
            )
        ]
        
        let dtos = metrics.map { metric in
            HealthMetricDTO(
                id: metric.id.uuidString,
                userId: metric.userId.uuidString,
                type: mapMetricTypeToDTO(metric.type),
                value: metric.value,
                unit: metric.unit,
                recordedAt: ISO8601DateFormatter().string(from: metric.recordedAt),
                source: metric.source?.rawValue,
                notes: metric.notes
            )
        }
        
        mockAPIClient.mockResponse = dtos
        
        // When
        let savedMetrics = try await sut.createBatch(metrics)
        
        // Then
        XCTAssertEqual(savedMetrics.count, 2)
        XCTAssertTrue(mockAPIClient.postCalled)
        XCTAssertEqual(mockPersistence.savedMetrics.count, 2)
    }
    
    // MARK: - Find Tests
    
    func test_findByUserIdAndDateRange_shouldFilterCorrectly() async throws {
        // Given
        let userId = UUID()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        // Create metrics at different times
        let pastMetric = HealthMetric(
            userId: userId,
            type: .steps,
            value: 5000,
            unit: "steps",
            recordedAt: yesterday
        )
        
        let todayMetric = HealthMetric(
            userId: userId,
            type: .steps,
            value: 10000,
            unit: "steps",
            recordedAt: now
        )
        
        let futureMetric = HealthMetric(
            userId: userId,
            type: .steps,
            value: 15000,
            unit: "steps",
            recordedAt: tomorrow
        )
        
        // Store in mock persistence
        mockPersistence.savedMetrics[pastMetric.id] = pastMetric
        mockPersistence.savedMetrics[todayMetric.id] = todayMetric
        mockPersistence.savedMetrics[futureMetric.id] = futureMetric
        
        // When - search for today's metrics
        let foundMetrics = try await sut.findByUserIdAndDateRange(
            userId: userId,
            startDate: now.addingTimeInterval(-3600), // 1 hour ago
            endDate: now.addingTimeInterval(3600)     // 1 hour from now
        )
        
        // Then
        XCTAssertEqual(foundMetrics.count, 1)
        XCTAssertEqual(foundMetrics.first?.value, 10000)
    }
    
    // MARK: - Sync Tests
    
    func test_syncPendingMetrics_shouldUploadOfflineData() async throws {
        // Given
        let metric1 = HealthMetric(
            userId: UUID(),
            type: .bloodPressureSystolic,
            value: 120,
            unit: "mmHg",
            recordedAt: Date()
        )
        
        let metric2 = HealthMetric(
            userId: UUID(),
            type: .bloodPressureDiastolic,
            value: 80,
            unit: "mmHg",
            recordedAt: Date()
        )
        
        // Mark as pending sync
        mockPersistence.pendingSyncMetrics = [metric1, metric2]
        
        let dtos = [metric1, metric2].map { metric in
            HealthMetricDTO(
                id: metric.id.uuidString,
                userId: metric.userId.uuidString,
                type: mapMetricTypeToDTO(metric.type),
                value: metric.value,
                unit: metric.unit,
                recordedAt: ISO8601DateFormatter().string(from: metric.recordedAt),
                source: metric.source?.rawValue,
                notes: metric.notes
            )
        }
        
        mockAPIClient.mockResponse = dtos
        
        // When
        let syncedCount = try await sut.syncPendingMetrics()
        
        // Then
        XCTAssertEqual(syncedCount, 2)
        XCTAssertTrue(mockPersistence.pendingSyncMetrics.isEmpty)
        XCTAssertTrue(mockAPIClient.postCalled)
    }
}

// MARK: - Mock Classes

private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var mockResponse: Any?
    var mockError: Error?
    var shouldFail = false
    
    var getCalled = false
    var postCalled = false
    var putCalled = false
    var deleteCalled = false
    
    func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T {
        getCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        postCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        putCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        deleteCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        deleteCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
    }
}

private final class MockPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    var savedMetrics: [UUID: HealthMetric] = [:]
    var pendingSyncMetrics: [HealthMetric] = []
    
    func save<T>(_ object: T) async throws where T: Identifiable {
        if let metric = object as? HealthMetric {
            savedMetrics[metric.id] = metric
        }
    }
    
    func fetch<T>(_ id: T.ID) async throws -> T? where T: Identifiable {
        return savedMetrics[id as! UUID] as? T
    }
    
    func delete<T>(type: T.Type, id: T.ID) async throws where T: Identifiable {
        savedMetrics.removeValue(forKey: id as! UUID)
    }
    
    func fetchAll<T>() async throws -> [T] where T: Identifiable {
        return savedMetrics.values.compactMap { $0 as? T }
    }
}

// MARK: - Helper Functions

private func mapMetricTypeToDTO(_ type: HealthMetricType) -> String {
    switch type {
    case .heartRate:
        return "heart_rate"
    case .bloodPressureSystolic:
        return "blood_pressure_systolic"
    case .bloodPressureDiastolic:
        return "blood_pressure_diastolic"
    case .bloodGlucose:
        return "blood_glucose"
    case .weight:
        return "weight"
    case .height:
        return "height"
    case .bodyTemperature:
        return "body_temperature"
    case .oxygenSaturation:
        return "oxygen_saturation"
    case .steps:
        return "steps"
    case .sleepDuration:
        return "sleep_duration"
    case .respiratoryRate:
        return "respiratory_rate"
    case .caloriesBurned:
        return "calories_burned"
    case .waterIntake:
        return "water_intake"
    case .exerciseDuration:
        return "exercise_duration"
    case .custom(let name):
        return name.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}

private enum APIError: Error {
    case networkError
    case unknown
}