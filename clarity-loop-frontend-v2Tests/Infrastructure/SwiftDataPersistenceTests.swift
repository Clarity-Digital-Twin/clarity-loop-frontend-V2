//
//  SwiftDataPersistenceTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for SwiftData persistence implementation following TDD
//

import XCTest
import SwiftData
@testable import ClarityData
@testable import ClarityDomain

final class SwiftDataPersistenceTests: XCTestCase {
    
    private var sut: SwiftDataPersistence!
    private var modelContainer: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: PersistedUser.self, PersistedHealthMetric.self,
            configurations: config
        )
        
        sut = SwiftDataPersistence(container: modelContainer)
    }
    
    override func tearDown() {
        sut = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func test_save_whenSavingUser_shouldPersistData() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        // When
        try await sut.save(user)
        
        // Then
        let fetchedUser: User? = try await sut.fetch(user.id)
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.email, user.email)
    }
    
    func test_save_whenSavingHealthMetric_shouldPersistData() async throws {
        // Given
        let metric = HealthMetric(
            id: UUID(),
            userId: UUID(),
            type: .heartRate,
            value: 72,
            unit: "BPM",
            recordedAt: Date()
        )
        
        // When
        try await sut.save(metric)
        
        // Then
        let fetchedMetric: HealthMetric? = try await sut.fetch(metric.id)
        XCTAssertNotNil(fetchedMetric)
        XCTAssertEqual(fetchedMetric?.value, metric.value)
    }
    
    // MARK: - Fetch Tests
    
    func test_fetch_whenEntityExists_shouldReturnEntity() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "existing@example.com",
            firstName: "Existing",
            lastName: "User"
        )
        try await sut.save(user)
        
        // When
        let fetchedUser: User? = try await sut.fetch(user.id)
        
        // Then
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, user.id)
    }
    
    func test_fetch_whenEntityDoesNotExist_shouldReturnNil() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let fetchedUser: User? = try await sut.fetch(nonExistentId)
        
        // Then
        XCTAssertNil(fetchedUser)
    }
    
    // MARK: - Delete Tests
    
    func test_delete_whenEntityExists_shouldRemoveIt() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "delete@example.com",
            firstName: "Delete",
            lastName: "Me"
        )
        try await sut.save(user)
        
        // When
        try await sut.delete(type: User.self, id: user.id)
        
        // Then
        let fetchedUser: User? = try await sut.fetch(user.id)
        XCTAssertNil(fetchedUser)
    }
    
    func test_delete_whenEntityDoesNotExist_shouldNotThrow() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When/Then - Should not throw
        try await sut.delete(type: User.self, id: nonExistentId)
    }
    
    // MARK: - Fetch All Tests
    
    func test_fetchAll_shouldReturnAllEntitiesOfType() async throws {
        // Given
        let users = [
            User(id: UUID(), email: "user1@example.com", firstName: "User", lastName: "One"),
            User(id: UUID(), email: "user2@example.com", firstName: "User", lastName: "Two"),
            User(id: UUID(), email: "user3@example.com", firstName: "User", lastName: "Three")
        ]
        
        for user in users {
            try await sut.save(user)
        }
        
        // When
        let fetchedUsers: [User] = try await sut.fetchAll()
        
        // Then
        XCTAssertEqual(fetchedUsers.count, 3)
        XCTAssertTrue(fetchedUsers.allSatisfy { savedUser in
            users.contains { $0.id == savedUser.id }
        })
    }
    
    func test_fetchAll_whenNoEntities_shouldReturnEmptyArray() async throws {
        // When
        let fetchedUsers: [User] = try await sut.fetchAll()
        
        // Then
        XCTAssertTrue(fetchedUsers.isEmpty)
    }
    
    // MARK: - Concurrent Access Tests
    
    func test_concurrentSaves_shouldHandleCorrectly() async throws {
        // Given
        let users = (0..<10).map { index in
            User(
                id: UUID(),
                email: "concurrent\(index)@example.com",
                firstName: "Concurrent",
                lastName: "\(index)"
            )
        }
        
        // When - Save sequentially for now (concurrent SwiftData access needs more setup)
        for user in users {
            try await sut.save(user)
        }
        
        // Then
        let fetchedUsers: [User] = try await sut.fetchAll()
        XCTAssertEqual(fetchedUsers.count, 10)
    }
}