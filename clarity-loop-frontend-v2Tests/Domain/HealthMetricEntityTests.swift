//
//  HealthMetricEntityTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for HealthMetric domain entity following TDD principles
//

import XCTest
@testable import ClarityDomain

final class HealthMetricEntityTests: XCTestCase {

    // MARK: - Test HealthMetric Creation

    func test_whenCreatingHealthMetric_withValidData_shouldInitializeCorrectly() {
        // Given
        let id = UUID()
        let userId = UUID()
        let type = HealthMetricType.heartRate
        let value = 72.0
        let unit = "BPM"
        let recordedAt = Date()

        // When
        let metric = HealthMetric(
            id: id,
            userId: userId,
            type: type,
            value: value,
            unit: unit,
            recordedAt: recordedAt
        )

        // Then
        XCTAssertEqual(metric.id, id)
        XCTAssertEqual(metric.userId, userId)
        XCTAssertEqual(metric.type, type)
        XCTAssertEqual(metric.value, value)
        XCTAssertEqual(metric.unit, unit)
        XCTAssertEqual(metric.recordedAt, recordedAt)
        XCTAssertNil(metric.source)
        XCTAssertNil(metric.notes)
    }

    // MARK: - Test Metric Type Properties

    func test_whenGettingMetricTypeProperties_shouldReturnCorrectValues() {
        // Given
        let testCases: [(HealthMetricType, String, String, ClosedRange<Double>?)] = [
            (.heartRate, "Heart Rate", "BPM", 40...200),
            (.bloodPressureSystolic, "Systolic Blood Pressure", "mmHg", 70...200),
            (.bloodPressureDiastolic, "Diastolic Blood Pressure", "mmHg", 40...130),
            (.bloodGlucose, "Blood Glucose", "mg/dL", 50...400),
            (.weight, "Weight", "kg", 20...300),
            (.height, "Height", "cm", 50...250),
            (.bodyTemperature, "Body Temperature", "°C", 35...42),
            (.oxygenSaturation, "Oxygen Saturation", "%", 70...100),
            (.steps, "Steps", "steps", 0...100000),
            (.sleepDuration, "Sleep Duration", "hours", 0...24)
        ]

        // When & Then
        for (type, expectedName, expectedUnit, expectedRange) in testCases {
            XCTAssertEqual(type.displayName, expectedName)
            XCTAssertEqual(type.defaultUnit, expectedUnit)
            XCTAssertEqual(type.validRange, expectedRange)
        }
    }

    // MARK: - Test Value Validation

    func test_whenValidatingValue_withinRange_shouldReturnTrue() {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 80,
            unit: "BPM",
            recordedAt: Date()
        )

        // When
        let isValid = metric.isValueValid

        // Then
        XCTAssertTrue(isValid)
    }

    func test_whenValidatingValue_outsideRange_shouldReturnFalse() {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 250, // Too high for heart rate
            unit: "BPM",
            recordedAt: Date()
        )

        // When
        let isValid = metric.isValueValid

        // Then
        XCTAssertFalse(isValid)
    }

    func test_whenValidatingValue_forTypeWithoutRange_shouldAlwaysReturnTrue() {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .custom("Custom Metric"),
            value: 999999,
            unit: "units",
            recordedAt: Date()
        )

        // When
        let isValid = metric.isValueValid

        // Then
        XCTAssertTrue(isValid)
    }

    // MARK: - Test BMI Calculation

    func test_whenCalculatingBMI_withWeightAndHeight_shouldReturnCorrectValue() {
        // Given
        let userId = UUID()
        let weight = HealthMetric(
            id: UUID(),
            userId: userId,
            type: .weight,
            value: 70, // kg
            unit: "kg",
            recordedAt: Date()
        )
        let height = HealthMetric(
            id: UUID(),
            userId: userId,
            type: .height,
            value: 175, // cm
            unit: "cm",
            recordedAt: Date()
        )

        // When
        let bmi = HealthMetric.calculateBMI(weight: weight, height: height)

        // Then
        XCTAssertNotNil(bmi)
        XCTAssertEqual(bmi!, 22.86, accuracy: 0.01)
    }

    // MARK: - Test Source Information

    func test_whenCreatingWithSource_shouldStoreSourceInfo() {
        // Given & When
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .steps,
            value: 10000,
            unit: "steps",
            recordedAt: Date(),
            source: .appleHealth
        )

        // Then
        XCTAssertEqual(metric.source, .appleHealth)
    }

    // MARK: - Test Codable

    func test_whenEncodingAndDecoding_shouldPreserveAllData() throws {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .bloodGlucose,
            value: 95,
            unit: "mg/dL",
            recordedAt: Date(),
            source: .manual,
            notes: "Before breakfast"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)

        let decoder = JSONDecoder()
        let decodedMetric = try decoder.decode(HealthMetric.self, from: data)

        // Then
        XCTAssertEqual(metric.id, decodedMetric.id)
        XCTAssertEqual(metric.userId, decodedMetric.userId)
        XCTAssertEqual(metric.type, decodedMetric.type)
        XCTAssertEqual(metric.value, decodedMetric.value)
        XCTAssertEqual(metric.unit, decodedMetric.unit)
        XCTAssertEqual(metric.source, decodedMetric.source)
        XCTAssertEqual(metric.notes, decodedMetric.notes)
    }
}
