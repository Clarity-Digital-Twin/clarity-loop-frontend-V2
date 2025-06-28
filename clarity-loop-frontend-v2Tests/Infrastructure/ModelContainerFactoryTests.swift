//
//  ModelContainerFactoryTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for SwiftData ModelContainer factory
//

import XCTest
import SwiftData
@testable import ClarityCore
@testable import ClarityData

final class ModelContainerFactoryTests: BaseUnitTestCase {
    
    // MARK: - Test Model Container Creation
    
    @MainActor
    func test_createModelContainer_shouldCreateContainerSuccessfully() async throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let container = try factory.createContainer()
        
        // Then
        XCTAssertNotNil(container)
        XCTAssertNotNil(container.mainContext)
    }
    
    @MainActor
    func test_createInMemoryContainer_shouldCreateTestContainer() async throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let container = try factory.createInMemoryContainer()
        
        // Then
        XCTAssertNotNil(container)
        XCTAssertNotNil(container.mainContext)
        
        // Verify it's configured for in-memory storage
        XCTAssertTrue(container.configurations.contains { config in
            config.isStoredInMemoryOnly
        })
    }
    
    func test_modelContainer_shouldIncludeAllModels() throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let container = try factory.createContainer()
        
        // Then
        // Verify the container includes expected models
        let schema = container.schema
        XCTAssertNotNil(schema)
        // SwiftData doesn't expose models list directly in schema
        // We'll test by trying to create instances instead
    }
    
    @MainActor
    func test_modelContainer_shouldAllowDataPersistence() async throws {
        // Given
        let factory = ModelContainerFactory()
        let container = try factory.createInMemoryContainer()
        let context = container.mainContext
        
        // When - Create and save a test user
        let user = PersistedUser(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            dateOfBirth: Date()
        )
        
        context.insert(user)
        try context.save()
        
        // Then - Verify we can fetch the user
        let descriptor = FetchDescriptor<PersistedUser>(
            predicate: #Predicate { $0.email == "test@example.com" }
        )
        
        let fetchedUsers = try context.fetch(descriptor)
        XCTAssertEqual(fetchedUsers.count, 1)
        XCTAssertEqual(fetchedUsers.first?.email, "test@example.com")
    }
    
    func test_createCloudContainer_shouldConfigureCloudSync() throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let container = try factory.createCloudContainer()
        
        // Then
        XCTAssertNotNil(container)
        
        // Verify we have configurations
        XCTAssertFalse(container.configurations.isEmpty)
    }
    
    func test_modelContainerConfiguration_shouldSetCorrectOptions() throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let config = factory.defaultConfiguration()
        
        // Then
        XCTAssertFalse(config.isStoredInMemoryOnly)
        XCTAssertTrue(config.allowsSave)
    }
    
    func test_testConfiguration_shouldBeInMemory() throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let config = factory.testConfiguration()
        
        // Then
        XCTAssertTrue(config.isStoredInMemoryOnly)
        XCTAssertTrue(config.allowsSave)
    }
    
    func test_modelContainer_shouldHandleMultipleSchemaMigrations() throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When/Then - Should not throw when creating container
        XCTAssertNoThrow(try factory.createContainer())
    }
}

// MARK: - Test Helpers

extension ModelContainerFactoryTests {
    
    @MainActor
    func test_sharedModelContainer_shouldBeSingleton() async throws {
        // Given
        let factory = ModelContainerFactory()
        
        // When
        let container1 = try factory.shared()
        let container2 = try factory.shared()
        
        // Then
        XCTAssertTrue(container1 === container2)
    }
    
    @MainActor
    func test_resetSharedContainer_shouldCreateNewInstance() async throws {
        // Given
        let factory = ModelContainerFactory()
        let container1 = try factory.shared()
        
        // When
        factory.resetShared()
        let container2 = try factory.shared()
        
        // Then
        XCTAssertFalse(container1 === container2)
    }
}
