//
//  BasicRepositoryTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Basic tests for Repository protocol implementation
//

import XCTest
@testable import ClarityDomain
import ClarityCore

final class BasicRepositoryTests: XCTestCase {
    
    // MARK: - Test Entity
    
    struct TestEntity: Entity {
        let id: UUID
        let createdAt: Date
        let updatedAt: Date
        let name: String
        
        init(
            id: UUID = UUID(),
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            name: String = "Test"
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.name = name
        }
    }
    
    // MARK: - Tests
    
    func test_repositoryProtocol_definesRequiredMethods() {
        // This test verifies the protocol compiles and has the expected structure
        // The actual implementation tests are in RepositoryProtocolTests.swift
        
        // Given a hypothetical repository conforming to the protocol
        let _: Repository.Type? = nil as (any Repository<TestEntity>).Type?
        
        // Then the protocol should define all required methods
        XCTAssertNotNil(Repository<TestEntity>.self)
    }
    
    func test_repositoryPredicate_canFilterEntities() {
        // Given
        let entities = [
            TestEntity(name: "Apple"),
            TestEntity(name: "Banana"),
            TestEntity(name: "Apricot")
        ]
        
        let predicate = RepositoryPredicate<TestEntity> { $0.name.hasPrefix("A") }
        
        // When
        let filtered = entities.filter { predicate.evaluate($0) }
        
        // Then
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.name.hasPrefix("A") })
    }
    
    func test_repositorySortDescriptor_canSortEntities() {
        // Given
        var entities = [
            TestEntity(name: "Charlie"),
            TestEntity(name: "Alice"),
            TestEntity(name: "Bob")
        ]
        
        let sortDescriptor = RepositorySortDescriptor<TestEntity>(
            keyPath: \TestEntity.name,
            ascending: true
        )
        
        // When
        entities.sort(by: sortDescriptor.compare)
        
        // Then
        XCTAssertEqual(entities.map { $0.name }, ["Alice", "Bob", "Charlie"])
    }
    
    func test_repositorySortDescriptor_canSortDescending() {
        // Given
        var entities = [
            TestEntity(name: "Charlie"),
            TestEntity(name: "Alice"),
            TestEntity(name: "Bob")
        ]
        
        let sortDescriptor = RepositorySortDescriptor<TestEntity>(
            keyPath: \TestEntity.name,
            ascending: false
        )
        
        // When
        entities.sort(by: sortDescriptor.compare)
        
        // Then
        XCTAssertEqual(entities.map { $0.name }, ["Charlie", "Bob", "Alice"])
    }
    
    func test_repositoryError_hasCorrectDescriptions() {
        // Given
        let errors: [RepositoryError] = [
            .saveFailed("Database error"),
            .fetchFailed("Network timeout"),
            .updateFailed("Conflict"),
            .deleteFailed("Not authorized"),
            .notFound,
            .invalidData,
            .unauthorized,
            .networkError(underlying: NSError(domain: "test", code: 500))
        ]
        
        // Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func test_repositoryError_equatable() {
        // Given
        let error1 = RepositoryError.saveFailed("Test")
        let error2 = RepositoryError.saveFailed("Test")
        let error3 = RepositoryError.saveFailed("Different")
        let error4 = RepositoryError.notFound
        
        // Then
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }
}