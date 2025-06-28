//
//  MockGeneratorTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for MockGenerator following BDD approach
//

import XCTest
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityCore

final class MockGeneratorTests: BaseUnitTestCase {
    
    // MARK: - User Mock Tests
    
    func test_generateUser_createsValidUser() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let user = mockGenerator.generateUser()
        
        // Then
        XCTAssertFalse(user.id.uuidString.isEmpty)
        XCTAssertTrue(user.email.contains("@"))
        XCTAssertTrue(user.email.contains("."))
        XCTAssertFalse(user.firstName.isEmpty)
        XCTAssertFalse(user.lastName.isEmpty)
    }
    
    func test_generateUser_withCustomEmail_usesProvidedEmail() {
        // Given
        let mockGenerator = MockGenerator()
        let customEmail = "custom@test.com"
        
        // When
        let user = mockGenerator.generateUser(email: customEmail)
        
        // Then
        XCTAssertEqual(user.email, customEmail)
    }
    
    func test_generateUsers_createsRequestedCount() {
        // Given
        let mockGenerator = MockGenerator()
        let count = 5
        
        // When
        let users = mockGenerator.generateUsers(count: count)
        
        // Then
        XCTAssertEqual(users.count, count)
        // Verify all users are unique
        let uniqueEmails = Set(users.map { $0.email })
        XCTAssertEqual(uniqueEmails.count, count)
    }
    
    // MARK: - HealthMetric Mock Tests
    
    func test_generateHealthMetric_createsValidMetric() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let metric = mockGenerator.generateHealthMetric()
        
        // Then
        XCTAssertFalse(metric.id.uuidString.isEmpty)
        XCTAssertTrue(metric.value > 0)
        XCTAssertNotNil(metric.type)
        XCTAssertNotNil(metric.source)
        XCTAssertTrue(metric.recordedAt <= Date())
    }
    
    func test_generateHealthMetric_withSpecificType_usesProvidedType() {
        // Given
        let mockGenerator = MockGenerator()
        let specificType = HealthMetricType.heartRate
        
        // When
        let metric = mockGenerator.generateHealthMetric(type: specificType)
        
        // Then
        XCTAssertEqual(metric.type, specificType)
    }
    
    func test_generateHealthMetrics_createsRealisticValues() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let heartRateMetric = mockGenerator.generateHealthMetric(type: .heartRate)
        let stepsMetric = mockGenerator.generateHealthMetric(type: .steps)
        let sleepMetric = mockGenerator.generateHealthMetric(type: .sleepDuration)
        
        // Then - verify realistic ranges
        XCTAssertTrue(heartRateMetric.value >= 40 && heartRateMetric.value <= 200)
        XCTAssertTrue(stepsMetric.value >= 0 && stepsMetric.value <= 50000)
        XCTAssertTrue(sleepMetric.value >= 0 && sleepMetric.value <= 24)
    }
    
    // MARK: - AuthToken Mock Tests
    
    func test_generateAuthToken_createsValidToken() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let token = mockGenerator.generateAuthToken()
        
        // Then
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertFalse(token.refreshToken.isEmpty)
        XCTAssertTrue(token.expiresIn > 0)
        XCTAssertFalse(token.userId.isEmpty)
    }
    
    // MARK: - Deterministic Mock Tests
    
    func test_generateUser_withSeed_producesSameResult() {
        // Given
        let mockGenerator1 = MockGenerator(seed: 12345)
        let mockGenerator2 = MockGenerator(seed: 12345)
        
        // When
        let user1 = mockGenerator1.generateUser()
        let user2 = mockGenerator2.generateUser()
        
        // Then
        XCTAssertEqual(user1.email, user2.email)
        XCTAssertEqual(user1.firstName, user2.firstName)
        XCTAssertEqual(user1.lastName, user2.lastName)
    }
    
    // MARK: - Random Data Generation Tests
    
    func test_randomEmail_generatesValidEmail() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let email = mockGenerator.randomEmail()
        
        // Then
        XCTAssertTrue(email.contains("@"))
        XCTAssertTrue(email.contains("."))
        let components = email.split(separator: "@")
        XCTAssertEqual(components.count, 2)
    }
    
    func test_randomName_generatesNonEmptyName() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let name = mockGenerator.randomName()
        
        // Then
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.count >= 2)
    }
    
    func test_randomPhoneNumber_generatesValidFormat() {
        // Given
        let mockGenerator = MockGenerator()
        
        // When
        let phone = mockGenerator.randomPhoneNumber()
        
        // Then
        XCTAssertEqual(phone.count, 14) // Format: (XXX) XXX-XXXX
        XCTAssertTrue(phone.hasPrefix("("))
        XCTAssertTrue(phone.contains(") "))
        XCTAssertTrue(phone.contains("-"))
    }
}
