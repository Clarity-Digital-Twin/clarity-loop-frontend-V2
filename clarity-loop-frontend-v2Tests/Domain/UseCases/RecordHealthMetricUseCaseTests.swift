//
//  RecordHealthMetricUseCaseTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for recording health metrics use case
//

import XCTest
@testable import ClarityDomain

final class RecordHealthMetricUseCaseTests: XCTestCase {
    
    // MARK: - Mock
    
    private final class MockHealthMetricRepository: HealthMetricRepositoryProtocol, @unchecked Sendable {
        var metrics: [UUID: HealthMetric] = [:]
        var shouldThrowError = false
        
        func create(_ metric: HealthMetric) async throws -> HealthMetric {
            if shouldThrowError {
                throw RepositoryError.saveFailed("Test error")
            }
            metrics[metric.id] = metric
            return metric
        }
        
        func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
            if shouldThrowError {
                throw RepositoryError.saveFailed("Test error")
            }
            for metric in metrics {
                self.metrics[metric.id] = metric
            }
            return metrics
        }
        
        func findById(_ id: UUID) async throws -> HealthMetric? {
            metrics[id]
        }
        
        func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
            metrics.values.filter { $0.userId == userId }
        }
        
        func findByUserIdAndDateRange(
            userId: UUID,
            startDate: Date,
            endDate: Date
        ) async throws -> [HealthMetric] {
            metrics.values.filter {
                $0.userId == userId &&
                $0.recordedAt >= startDate &&
                $0.recordedAt <= endDate
            }
        }
        
        func findByUserIdAndType(
            userId: UUID,
            type: HealthMetricType
        ) async throws -> [HealthMetric] {
            metrics.values.filter {
                $0.userId == userId && $0.type == type
            }
        }
        
        func update(_ metric: HealthMetric) async throws -> HealthMetric {
            metrics[metric.id] = metric
            return metric
        }
        
        func delete(_ id: UUID) async throws {
            metrics.removeValue(forKey: id)
        }
        
        func deleteAllForUser(_ userId: UUID) async throws {
            metrics = metrics.filter { $0.value.userId != userId }
        }
        
        func getLatestByType(
            userId: UUID,
            type: HealthMetricType
        ) async throws -> HealthMetric? {
            metrics.values
                .filter { $0.userId == userId && $0.type == type }
                .max { $0.recordedAt < $1.recordedAt }
        }
    }
    
    // MARK: - Tests
    
    func test_whenRecordingMetric_withValidData_shouldSaveSuccessfully() async throws {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        let userId = UUID()
        
        // When
        let result = try await useCase.execute(
            userId: userId,
            type: .heartRate,
            value: 75,
            unit: "BPM",
            source: .manual,
            notes: "Resting heart rate"
        )
        
        // Then
        XCTAssertEqual(result.userId, userId)
        XCTAssertEqual(result.type, .heartRate)
        XCTAssertEqual(result.value, 75)
        XCTAssertEqual(result.unit, "BPM")
        XCTAssertEqual(result.source, .manual)
        XCTAssertEqual(result.notes, "Resting heart rate")
        XCTAssertTrue(result.isValueValid)
    }
    
    func test_whenRecordingMetric_withInvalidValue_shouldThrowError() async {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        
        // When & Then
        do {
            _ = try await useCase.execute(
                userId: UUID(),
                type: .heartRate,
                value: 300, // Invalid heart rate
                unit: "BPM"
            )
            XCTFail("Should have thrown validation error")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func test_whenRecordingBatchMetrics_shouldSaveAll() async throws {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        let userId = UUID()
        
        let metricsData: [(HealthMetricType, Double, String)] = [
            (.heartRate, 72, "BPM"),
            (.bloodPressureSystolic, 120, "mmHg"),
            (.bloodPressureDiastolic, 80, "mmHg")
        ]
        
        // When
        let results = try await useCase.executeBatch(
            userId: userId,
            metrics: metricsData.map { type, value, unit in
                MetricData(type: type, value: value, unit: unit, source: .manual, notes: nil)
            }
        )
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.userId == userId })
        XCTAssertTrue(results.allSatisfy { $0.isValueValid })
    }
    
    func test_whenRecordingMetric_withDefaultUnit_shouldUseMetricTypeDefault() async throws {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        
        // When
        let result = try await useCase.execute(
            userId: UUID(),
            type: .weight,
            value: 70,
            unit: nil // Should use default
        )
        
        // Then
        XCTAssertEqual(result.unit, "kg") // Default for weight
    }
    
    func test_whenCheckingDuplicates_withRecentMetric_shouldDetectDuplicate() async throws {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        let userId = UUID()
        
        // First record a metric
        _ = try await useCase.execute(
            userId: userId,
            type: .heartRate,
            value: 75,
            unit: "BPM"
        )
        
        // When checking for duplicate
        let isDuplicate = try await useCase.isDuplicateMetric(
            userId: userId,
            type: .heartRate,
            value: 75,
            withinMinutes: 5
        )
        
        // Then
        XCTAssertTrue(isDuplicate)
    }
    
    func test_whenCheckingDuplicates_withOldMetric_shouldNotDetectDuplicate() async throws {
        // Given
        let repository = MockHealthMetricRepository()
        let useCase = RecordHealthMetricUseCase(repository: repository)
        let userId = UUID()
        
        // Record a metric with old timestamp
        let oldMetric = HealthMetric(
            userId: userId,
            type: .heartRate,
            value: 75,
            unit: "BPM",
            recordedAt: Date().addingTimeInterval(-600) // 10 minutes ago
        )
        _ = try await repository.create(oldMetric)
        
        // When checking for duplicate
        let isDuplicate = try await useCase.isDuplicateMetric(
            userId: userId,
            type: .heartRate,
            value: 75,
            withinMinutes: 5
        )
        
        // Then
        XCTAssertFalse(isDuplicate)
    }
}