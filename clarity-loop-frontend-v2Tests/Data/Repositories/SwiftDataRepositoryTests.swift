//
//  SwiftDataRepositoryTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for SwiftDataRepository implementation
//

import XCTest
import SwiftData
@testable import ClarityData
@testable import ClarityDomain
@testable import ClarityCore

final class SwiftDataRepositoryTests: XCTestCase {
    
    // MARK: - Test Model
    
    @Model
    final class TestModel {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var name: String
        var value: Int
        
        init(
            id: UUID = UUID(),
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            name: String = "Test",
            value: Int = 0
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.name = name
            self.value = value
        }
    }
    
    // MARK: - Test Entity
    
    struct TestEntity: Entity, Sendable {
        let id: UUID
        let createdAt: Date
        let updatedAt: Date
        let name: String
        let value: Int
        
        init(
            id: UUID = UUID(),
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            name: String = "Test",
            value: Int = 0
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.name = name
            self.value = value
        }
    }
    
    // MARK: - Properties
    
    private var modelContainer: ModelContainer!
    private var sut: SwiftDataRepository<TestEntity, TestModel, TestEntityMapper>!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        let schema = Schema([TestModel.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        
        // Create repository
        sut = SwiftDataRepository(
            modelContainer: modelContainer,
            modelType: TestModel.self,
            mapper: TestEntityMapper()
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Create Tests
    
    func test_create_shouldPersistEntity() async throws {
        // Given
        let entity = TestEntity(name: "New Entity", value: 42)
        
        // When
        let created = try await sut.create(entity)
        
        // Then
        XCTAssertEqual(created.id, entity.id)
        XCTAssertEqual(created.name, entity.name)
        XCTAssertEqual(created.value, entity.value)
        
        // Verify persistence
        let fetched = try await sut.read(id: entity.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, entity.name)
    }
    
    func test_create_withDuplicateId_shouldThrowError() async throws {
        // Given
        let id = UUID()
        let entity1 = TestEntity(id: id, name: "First")
        let entity2 = TestEntity(id: id, name: "Second")
        
        _ = try await sut.create(entity1)
        
        // When/Then
        do {
            _ = try await sut.create(entity2)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    // MARK: - Read Tests
    
    func test_read_withExistingId_shouldReturnEntity() async throws {
        // Given
        let entity = TestEntity(name: "Existing", value: 100)
        _ = try await sut.create(entity)
        
        // When
        let fetched = try await sut.read(id: entity.id)
        
        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, entity.id)
        XCTAssertEqual(fetched?.name, entity.name)
        XCTAssertEqual(fetched?.value, entity.value)
    }
    
    func test_read_withNonExistingId_shouldReturnNil() async throws {
        // Given
        let nonExistingId = UUID()
        
        // When
        let fetched = try await sut.read(id: nonExistingId)
        
        // Then
        XCTAssertNil(fetched)
    }
    
    // MARK: - Update Tests
    
    func test_update_withExistingEntity_shouldPersistChanges() async throws {
        // Given
        let entity = TestEntity(name: "Original", value: 1)
        _ = try await sut.create(entity)
        
        let updated = TestEntity(
            id: entity.id,
            createdAt: entity.createdAt,
            updatedAt: Date(),
            name: "Updated",
            value: 2
        )
        
        // When
        let result = try await sut.update(updated)
        
        // Then
        XCTAssertEqual(result.name, "Updated")
        XCTAssertEqual(result.value, 2)
        
        // Verify persistence
        let fetched = try await sut.read(id: entity.id)
        XCTAssertEqual(fetched?.name, "Updated")
        XCTAssertEqual(fetched?.value, 2)
    }
    
    func test_update_withNonExistingEntity_shouldThrowError() async throws {
        // Given
        let entity = TestEntity(name: "Non-existing")
        
        // When/Then
        do {
            _ = try await sut.update(entity)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if let repoError = error as? RepositoryError {
                XCTAssertEqual(repoError, .notFound)
            }
        }
    }
    
    // MARK: - Delete Tests
    
    func test_delete_withExistingId_shouldRemoveEntity() async throws {
        // Given
        let entity = TestEntity(name: "To Delete")
        _ = try await sut.create(entity)
        
        // When
        try await sut.delete(id: entity.id)
        
        // Then
        let fetched = try await sut.read(id: entity.id)
        XCTAssertNil(fetched)
    }
    
    func test_delete_withNonExistingId_shouldThrowError() async throws {
        // Given
        let nonExistingId = UUID()
        
        // When/Then
        do {
            try await sut.delete(id: nonExistingId)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
            if let repoError = error as? RepositoryError {
                XCTAssertEqual(repoError, .notFound)
            }
        }
    }
    
    // MARK: - List Tests
    
    func test_list_shouldReturnAllEntities() async throws {
        // Given
        let entities = [
            TestEntity(name: "Entity 1", value: 1),
            TestEntity(name: "Entity 2", value: 2),
            TestEntity(name: "Entity 3", value: 3)
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        // When
        let results = try await sut.list()
        
        // Then
        XCTAssertEqual(results.count, 3)
        let names = results.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Entity 1", "Entity 2", "Entity 3"])
    }
    
    func test_list_withPredicate_shouldFilterResults() async throws {
        // Given
        let entities = [
            TestEntity(name: "Apple", value: 10),
            TestEntity(name: "Banana", value: 20),
            TestEntity(name: "Apricot", value: 30)
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.name.hasPrefix("A") }
        
        // When
        let results = try await sut.list(predicate: predicate)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.name.hasPrefix("A") })
    }
    
    func test_list_withSorting_shouldOrderResults() async throws {
        // Given
        let entities = [
            TestEntity(name: "Charlie", value: 30),
            TestEntity(name: "Alice", value: 10),
            TestEntity(name: "Bob", value: 20)
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        let sortDescriptor = RepositorySortDescriptor<TestEntity>(
            keyPath: \TestEntity.value,
            ascending: true
        )
        
        // When
        let results = try await sut.list(sortBy: [sortDescriptor])
        
        // Then
        XCTAssertEqual(results.map { $0.value }, [10, 20, 30])
    }
    
    // MARK: - Count Tests
    
    func test_count_shouldReturnCorrectTotal() async throws {
        // Given
        let entities = [
            TestEntity(name: "Entity 1"),
            TestEntity(name: "Entity 2"),
            TestEntity(name: "Entity 3")
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        // When
        let count = try await sut.count()
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    func test_count_withPredicate_shouldReturnFilteredCount() async throws {
        // Given
        let entities = [
            TestEntity(name: "Active", value: 1),
            TestEntity(name: "Inactive", value: 0),
            TestEntity(name: "Active", value: 1)
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.value > 0 }
        
        // When
        let count = try await sut.count(predicate: predicate)
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    // MARK: - Delete All Tests
    
    func test_deleteAll_shouldRemoveAllEntities() async throws {
        // Given
        let entities = [
            TestEntity(name: "Entity 1"),
            TestEntity(name: "Entity 2"),
            TestEntity(name: "Entity 3")
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        // When
        try await sut.deleteAll()
        
        // Then
        let count = try await sut.count()
        XCTAssertEqual(count, 0)
    }
    
    func test_deleteAll_withPredicate_shouldRemoveMatchingEntities() async throws {
        // Given
        let entities = [
            TestEntity(name: "Keep", value: 0),
            TestEntity(name: "Delete", value: 1),
            TestEntity(name: "Delete", value: 1)
        ]
        
        for entity in entities {
            _ = try await sut.create(entity)
        }
        
        let predicate = RepositoryPredicate<TestEntity> { $0.value > 0 }
        
        // When
        try await sut.deleteAll(predicate: predicate)
        
        // Then
        let remaining = try await sut.list()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "Keep")
    }
    
    // MARK: - Transaction Tests
    
    func test_transaction_shouldExecuteAtomically() async throws {
        // Given
        let entity1 = TestEntity(name: "Transaction 1")
        let entity2 = TestEntity(name: "Transaction 2")
        
        // When
        try await sut.transaction { repository in
            _ = try await repository.create(entity1)
            _ = try await repository.create(entity2)
        }
        
        // Then
        let count = try await sut.count()
        XCTAssertEqual(count, 2)
    }
    
    func test_transaction_withError_shouldRollback() async throws {
        // Given
        let entity = TestEntity(name: "Will Rollback")
        let initialCount = try await sut.count()
        
        // When
        do {
            try await sut.transaction { repository in
                _ = try await repository.create(entity)
                throw RepositoryError.saveFailed("Test rollback")
            }
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
        
        // Then
        let finalCount = try await sut.count()
        XCTAssertEqual(finalCount, initialCount)
    }
}

// MARK: - Entity Mapper

private struct TestEntityMapper: EntityMapper, Sendable {
    typealias Entity = TestEntity
    typealias Model = SwiftDataRepositoryTests.TestModel
    
    func toModel(_ entity: Entity) -> Model {
        Model(
            id: entity.id,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            name: entity.name,
            value: entity.value
        )
    }
    
    func toEntity(_ model: Model) -> Entity {
        Entity(
            id: model.id,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            name: model.name,
            value: model.value
        )
    }
}