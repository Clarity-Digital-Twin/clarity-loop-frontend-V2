//
//  EntityProtocolTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for Entity protocol
//

import XCTest
@testable import ClarityDomain

final class EntityProtocolTests: XCTestCase {
    
    // MARK: - Test Entity Protocol Requirements
    
    func test_entityProtocol_shouldRequireId() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let entity = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Then
        XCTAssertNotNil(entity.id)
        XCTAssertTrue(type(of: entity.id) == UUID.self)
    }
    
    func test_entityProtocol_shouldRequireCreatedAt() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let now = Date()
        let entity = TestEntity(
            id: UUID(),
            createdAt: now,
            updatedAt: now
        )
        
        // Then
        XCTAssertEqual(entity.createdAt, now)
    }
    
    func test_entityProtocol_shouldRequireUpdatedAt() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let createdAt = Date()
        let updatedAt = Date().addingTimeInterval(60)
        let entity = TestEntity(
            id: UUID(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        
        // Then
        XCTAssertEqual(entity.updatedAt, updatedAt)
        XCTAssertTrue(entity.updatedAt > entity.createdAt)
    }
    
    func test_entityProtocol_shouldConformToIdentifiable() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let entity = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Then - Verify Identifiable conformance
        XCTAssertTrue((entity as Any) is any Identifiable)
    }
    
    func test_entityProtocol_shouldBeEquatable() {
        // Given
        struct TestEntity: Entity, Equatable {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        let id = UUID()
        let date = Date()
        
        // When
        let entity1 = TestEntity(id: id, createdAt: date, updatedAt: date)
        let entity2 = TestEntity(id: id, createdAt: date, updatedAt: date)
        let entity3 = TestEntity(id: UUID(), createdAt: date, updatedAt: date)
        
        // Then
        XCTAssertEqual(entity1, entity2)
        XCTAssertNotEqual(entity1, entity3)
    }
    
    func test_entityProtocol_shouldProvideDefaultEquality() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
            let name: String
        }
        
        let id = UUID()
        let date = Date()
        
        // When
        let entity1 = TestEntity(id: id, createdAt: date, updatedAt: date, name: "Test")
        let entity2 = TestEntity(id: id, createdAt: date, updatedAt: date, name: "Different")
        
        // Then - Default equality should be based on ID only
        XCTAssertTrue(entity1.isEqual(to: entity2))
    }
    
    func test_entityProtocol_shouldProvideHashableConformance() {
        // Given
        struct TestEntity: Entity, Hashable {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let entity = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Then
        let set = Set([entity])
        XCTAssertEqual(set.count, 1)
        XCTAssertTrue(set.contains(entity))
    }
    
    func test_entityProtocol_withDifferentConcreteTypes() {
        // Given
        struct User: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
            let email: String
        }
        
        struct HealthMetric: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
            let type: String
            let value: Double
        }
        
        // When
        let user = User(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            email: "test@example.com"
        )
        
        let metric = HealthMetric(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            type: "steps",
            value: 10000
        )
        
        // Then
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(metric.id)
        XCTAssertNotEqual(user.id, metric.id)
    }
    
    func test_entityProtocol_shouldSupportCodable() {
        // Given
        struct TestEntity: Entity, Codable {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        let entity = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(entity)
            let decoded = try decoder.decode(TestEntity.self, from: data)
            
            // Then
            XCTAssertEqual(decoded.id, entity.id)
            XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, entity.createdAt.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, entity.updatedAt.timeIntervalSince1970, accuracy: 0.001)
        } catch {
            XCTFail("Codable conformance failed: \(error)")
        }
    }
    
    func test_entityProtocol_shouldProvideConvenienceInitializer() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
            
            init(id: UUID = UUID()) {
                let now = Date()
                self.id = id
                self.createdAt = now
                self.updatedAt = now
            }
        }
        
        // When
        let entity = TestEntity()
        
        // Then
        XCTAssertNotNil(entity.id)
        XCTAssertEqual(entity.createdAt, entity.updatedAt)
    }
}

// MARK: - Test Protocol Extensions

extension EntityProtocolTests {
    
    func test_entityExtension_shouldProvideIsEqualImplementation() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
            let data: String
        }
        
        let id = UUID()
        
        // When
        let entity1 = TestEntity(
            id: id,
            createdAt: Date(),
            updatedAt: Date(),
            data: "Data1"
        )
        
        let entity2 = TestEntity(
            id: id,
            createdAt: Date().addingTimeInterval(100),
            updatedAt: Date().addingTimeInterval(200),
            data: "Data2"
        )
        
        let entity3 = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            data: "Data3"
        )
        
        // Then
        XCTAssertTrue(entity1.isEqual(to: entity2))  // Same ID
        XCTAssertFalse(entity1.isEqual(to: entity3)) // Different ID
    }
    
    func test_entityExtension_shouldProvideTimeBasedHelpers() {
        // Given
        struct TestEntity: Entity {
            let id: UUID
            let createdAt: Date
            let updatedAt: Date
        }
        
        // When
        let oldEntity = TestEntity(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
            updatedAt: Date().addingTimeInterval(-1800)  // 30 min ago
        )
        
        let newEntity = TestEntity(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Then
        XCTAssertTrue(oldEntity.wasUpdated)
        XCTAssertFalse(newEntity.wasUpdated)
    }
}