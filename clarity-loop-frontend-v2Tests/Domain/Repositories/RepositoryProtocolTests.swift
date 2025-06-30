//
//  RepositoryProtocolTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for Repository Protocol
//

import XCTest
@testable import ClarityDomain
import ClarityCore

final class RepositoryProtocolTests: XCTestCase {
    
    // MARK: - Test Entity
    
    struct TestEntity: Entity, Sendable {
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
    
    // MARK: - Mock Repository
    
    actor MockRepository<T: Entity & Sendable>: Repository {
        typealias EntityType = T
        
        private var storage: [UUID: T] = [:]
        private var shouldFailNext = false
        
        func create(_ entity: T) async throws -> T {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.saveFailed("Mock failure")
            }
            storage[entity.id] = entity
            return entity
        }
        
        func read(id: UUID) async throws -> T? {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.fetchFailed("Mock failure")
            }
            return storage[id]
        }
        
        func update(_ entity: T) async throws -> T {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.updateFailed("Mock failure")
            }
            guard storage[entity.id] != nil else {
                throw RepositoryError.notFound
            }
            storage[entity.id] = entity
            return entity
        }
        
        func delete(id: UUID) async throws {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.deleteFailure("Mock failure")
            }
            guard storage[id] != nil else {
                throw RepositoryError.notFound
            }
            storage.removeValue(forKey: id)
        }
        
        func list(predicate: RepositoryPredicate<T>? = nil, sortBy: [RepositorySortDescriptor<T>] = []) async throws -> [T] {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.fetchFailed("Mock failure")
            }
            
            var results = Array(storage.values)
            
            // Apply predicate if provided
            if let predicate = predicate {
                results = results.filter { predicate.evaluate($0) }
            }
            
            // Apply sorting
            for descriptor in sortBy.reversed() {
                results.sort { descriptor.compare($0, $1) }
            }
            
            return results
        }
        
        func count(predicate: RepositoryPredicate<T>? = nil) async throws -> Int {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.fetchFailed("Mock failure")
            }
            
            if let predicate = predicate {
                return storage.values.filter { predicate.evaluate($0) }.count
            }
            return storage.count
        }
        
        func deleteAll(predicate: RepositoryPredicate<T>? = nil) async throws {
            if shouldFailNext {
                shouldFailNext = false
                throw RepositoryError.deleteFailure("Mock failure")
            }
            
            if let predicate = predicate {
                let idsToDelete = storage.values
                    .filter { predicate.evaluate($0) }
                    .map { $0.id }
                
                for id in idsToDelete {
                    storage.removeValue(forKey: id)
                }
            } else {
                storage.removeAll()
            }
        }
        
        func setFailureForNextOperation() {
            shouldFailNext = true
        }
    }
    
    // MARK: - Tests
    
    func test_create_shouldStoreEntity() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entity = TestEntity(name: "New Entity")
        
        // When
        let created = try await repository.create(entity)
        
        // Then
        XCTAssertEqual(created.id, entity.id)
        XCTAssertEqual(created.name, entity.name)
        
        let retrieved = try await repository.read(id: entity.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, entity.name)
    }
    
    func test_read_withExistingId_shouldReturnEntity() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entity = TestEntity(name: "Existing Entity")
        _ = try await repository.create(entity)
        
        // When
        let retrieved = try await repository.read(id: entity.id)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, entity.id)
        XCTAssertEqual(retrieved?.name, entity.name)
    }
    
    func test_read_withNonExistingId_shouldReturnNil() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let nonExistingId = UUID()
        
        // When
        let retrieved = try await repository.read(id: nonExistingId)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func test_update_withExistingEntity_shouldUpdateEntity() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entity = TestEntity(name: "Original")
        _ = try await repository.create(entity)
        
        let updatedEntity = TestEntity(
            id: entity.id,
            createdAt: entity.createdAt,
            updatedAt: Date(),
            name: "Updated"
        )
        
        // When
        let result = try await repository.update(updatedEntity)
        
        // Then
        XCTAssertEqual(result.name, "Updated")
        
        let retrieved = try await repository.read(id: entity.id)
        XCTAssertEqual(retrieved?.name, "Updated")
    }
    
    func test_update_withNonExistingEntity_shouldThrowError() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entity = TestEntity(name: "Non-existing")
        
        // When/Then
        do {
            _ = try await repository.update(entity)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if let repoError = error as? RepositoryError {
                XCTAssertEqual(repoError, .notFound)
            }
        }
    }
    
    func test_delete_withExistingId_shouldRemoveEntity() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entity = TestEntity(name: "To Delete")
        _ = try await repository.create(entity)
        
        // When
        try await repository.delete(id: entity.id)
        
        // Then
        let retrieved = try await repository.read(id: entity.id)
        XCTAssertNil(retrieved)
    }
    
    func test_delete_withNonExistingId_shouldThrowError() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let nonExistingId = UUID()
        
        // When/Then
        do {
            try await repository.delete(id: nonExistingId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if let repoError = error as? RepositoryError {
                XCTAssertEqual(repoError, .notFound)
            }
        }
    }
    
    func test_list_shouldReturnAllEntities() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Entity 1"),
            TestEntity(name: "Entity 2"),
            TestEntity(name: "Entity 3")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        // When
        let results = try await repository.list()
        
        // Then
        XCTAssertEqual(results.count, 3)
        let names = results.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Entity 1", "Entity 2", "Entity 3"])
    }
    
    func test_list_withPredicate_shouldFilterResults() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Apple"),
            TestEntity(name: "Banana"),
            TestEntity(name: "Apricot")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.name.hasPrefix("A") }
        
        // When
        let results = try await repository.list(predicate: predicate)
        
        // Then
        XCTAssertEqual(results.count, 2)
        let names = results.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Apple", "Apricot"])
    }
    
    func test_list_withSorting_shouldReturnSortedResults() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Charlie"),
            TestEntity(name: "Alice"),
            TestEntity(name: "Bob")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        let sortDescriptor = RepositorySortDescriptor<TestEntity>(compare: { $0.name < $1.name })
        
        // When
        let results = try await repository.list(sortBy: [sortDescriptor])
        
        // Then
        XCTAssertEqual(results.count, 3)
        let names = results.map { $0.name }
        XCTAssertEqual(names, ["Alice", "Bob", "Charlie"])
    }
    
    func test_count_shouldReturnCorrectCount() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Entity 1"),
            TestEntity(name: "Entity 2"),
            TestEntity(name: "Entity 3")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        // When
        let count = try await repository.count()
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    func test_count_withPredicate_shouldReturnFilteredCount() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Apple"),
            TestEntity(name: "Banana"),
            TestEntity(name: "Apricot")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.name.hasPrefix("A") }
        
        // When
        let count = try await repository.count(predicate: predicate)
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func test_deleteAll_shouldRemoveAllEntities() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Entity 1"),
            TestEntity(name: "Entity 2"),
            TestEntity(name: "Entity 3")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        // When
        try await repository.deleteAll()
        
        // Then
        let count = try await repository.count()
        XCTAssertEqual(count, 0)
    }
    
    func test_deleteAll_withPredicate_shouldRemoveMatchingEntities() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        let entities = [
            TestEntity(name: "Apple"),
            TestEntity(name: "Banana"),
            TestEntity(name: "Apricot")
        ]
        
        for entity in entities {
            _ = try await repository.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.name.hasPrefix("A") }
        
        // When
        try await repository.deleteAll(predicate: predicate)
        
        // Then
        let remaining = try await repository.list()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "Banana")
    }
    
    // MARK: - Error Handling Tests
    
    func test_create_withError_shouldThrowRepositoryError() async throws {
        // Given
        let repository = MockRepository<TestEntity>()
        await repository.setFailureForNextOperation()
        let entity = TestEntity(name: "Will Fail")
        
        // When/Then
        do {
            _ = try await repository.create(entity)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if let repoError = error as? RepositoryError {
                XCTAssertEqual(repoError, .saveFailure("Mock failure"))
            }
        }
    }
}
