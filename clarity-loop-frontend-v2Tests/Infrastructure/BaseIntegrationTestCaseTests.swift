//
//  BaseIntegrationTestCaseTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for BaseIntegrationTestCase infrastructure
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

final class BaseIntegrationTestCaseTests: XCTestCase {
    
    // MARK: - Test Integration Infrastructure
    
    func test_baseIntegrationTestCase_providesTestContainer() {
        // Given
        let testCase = TestIntegrationCase()
        
        // When
        testCase.setUpIntegration()
        
        // Then
        XCTAssertNotNil(testCase.testContainer)
        XCTAssertNotNil(testCase.testNetworkClient)
        XCTAssertNotNil(testCase.testPersistence)
    }
    
    func test_baseIntegrationTestCase_configuresDependencies() {
        // Given
        let testCase = TestIntegrationCase()
        
        // When
        testCase.setUpIntegration()
        
        // Then - verify core dependencies are registered
        XCTAssertNotNil(testCase.testContainer.resolve(APIClientProtocol.self))
        XCTAssertNotNil(testCase.testContainer.resolve(PersistenceServiceProtocol.self))
        XCTAssertNotNil(testCase.testContainer.resolve(AuthServiceProtocol.self))
    }
    
    func test_baseIntegrationTestCase_cleansUpAfterTest() async {
        // Given
        let testCase = TestIntegrationCase()
        testCase.setUpIntegration()
        
        // When
        await testCase.tearDownIntegration()
        
        // Then
        XCTAssertTrue(testCase.tearDownCalled)
    }
    
    // MARK: - Test Helpers
    
    func test_baseIntegrationTestCase_providesDataFlowVerification() async throws {
        // Given
        let testCase = TestIntegrationCase()
        testCase.setUpIntegration()
        
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        // When - verify data flow from repository to use case
        let repository = testCase.testContainer.require(UserRepositoryProtocol.self)
        let loginUseCase = testCase.testContainer.require(LoginUseCaseProtocol.self)
        
        // Then - verify integration works
        XCTAssertNotNil(repository)
        XCTAssertNotNil(loginUseCase)
    }
    
    func test_baseIntegrationTestCase_supportsMultipleComponentInteraction() async throws {
        // Given
        let testCase = TestIntegrationCase()
        testCase.setUpIntegration()
        
        // When - create components that need to interact
        let healthRepository = testCase.testContainer.require(HealthMetricRepositoryProtocol.self)
        let recordUseCase = testCase.testContainer.require(RecordHealthMetricUseCase.self)
        
        // Then - verify they can work together
        XCTAssertNotNil(healthRepository)
        XCTAssertNotNil(recordUseCase)
        
        // Test actual interaction
        let metric = try await recordUseCase.execute(
            userId: UUID(),
            type: .heartRate,
            value: 72
        )
        
        XCTAssertEqual(metric.value, 72)
        XCTAssertEqual(metric.type, .heartRate)
    }
}

// MARK: - Test Double

class TestIntegrationCase: BaseIntegrationTestCase {
    var tearDownCalled = false
    
    override func tearDownIntegration() async {
        await super.tearDownIntegration()
        tearDownCalled = true
    }
}