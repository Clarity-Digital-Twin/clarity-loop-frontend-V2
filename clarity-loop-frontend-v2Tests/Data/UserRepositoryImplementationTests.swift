//
//  UserRepositoryImplementationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for UserRepository implementation following TDD
//

import XCTest
@testable import ClarityData
@testable import ClarityDomain

final class UserRepositoryImplementationTests: XCTestCase {
    
    private var sut: UserRepositoryImplementation!
    private var mockAPIClient: MockAPIClient!
    private var mockPersistence: MockPersistenceService!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockPersistence = MockPersistenceService()
        sut = UserRepositoryImplementation(
            apiClient: mockAPIClient,
            persistence: mockPersistence
        )
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    
    func test_create_whenAPISucceeds_shouldSaveToLocalAndReturnUser() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        let expectedDTO = UserDTO(
            id: user.id.uuidString,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            createdAt: ISO8601DateFormatter().string(from: user.createdAt),
            lastLoginAt: user.lastLoginAt.map { ISO8601DateFormatter().string(from: $0) }
        )
        
        mockAPIClient.mockResponse = expectedDTO
        
        // When
        let savedUser = try await sut.create(user)
        
        // Then
        XCTAssertEqual(savedUser.id, user.id)
        XCTAssertEqual(mockPersistence.savedUsers.count, 1)
        XCTAssertTrue(mockAPIClient.postCalled)
    }
    
    func test_create_whenAPIFails_shouldThrowError() async {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        mockAPIClient.shouldFail = true
        mockAPIClient.mockError = APIError.networkError
        
        // When/Then
        do {
            _ = try await sut.create(user)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }
    
    // MARK: - Find Tests
    
    func test_findById_whenExistsLocally_shouldReturnFromCache() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "cached@example.com",
            firstName: "Cached",
            lastName: "User"
        )
        mockPersistence.savedUsers[user.id] = user
        
        // When
        let foundUser = try await sut.findById(user.id)
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.id, user.id)
        XCTAssertFalse(mockAPIClient.getCalled) // Should not call API
    }
    
    func test_findById_whenNotLocal_shouldFetchFromAPI() async throws {
        // Given
        let userId = UUID()
        let userDTO = UserDTO(
            id: userId.uuidString,
            email: "remote@example.com",
            firstName: "Remote",
            lastName: "User",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            lastLoginAt: nil
        )
        
        mockAPIClient.mockResponse = userDTO
        
        // When
        let foundUser = try await sut.findById(userId)
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.email, "remote@example.com")
        XCTAssertTrue(mockAPIClient.getCalled)
        XCTAssertEqual(mockPersistence.savedUsers.count, 1) // Should cache
    }
    
    // MARK: - Update Tests
    
    func test_update_shouldUpdateBothLocalAndRemote() async throws {
        // Given
        let user = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Original",
            lastName: "User"
        )
        
        // First save it
        mockPersistence.savedUsers[user.id] = user
        
        // Update the user
        let userWithLogin = user.withUpdatedLastLogin()
        
        let updatedDTO = UserDTO(
            id: userWithLogin.id.uuidString,
            email: userWithLogin.email,
            firstName: userWithLogin.firstName,
            lastName: userWithLogin.lastName,
            createdAt: ISO8601DateFormatter().string(from: userWithLogin.createdAt),
            lastLoginAt: userWithLogin.lastLoginAt.map { ISO8601DateFormatter().string(from: $0) }
        )
        
        mockAPIClient.mockResponse = updatedDTO
        
        // When
        let updatedUser = try await sut.update(userWithLogin)
        
        // Then
        XCTAssertNotNil(updatedUser.lastLoginAt)
        XCTAssertTrue(mockAPIClient.putCalled)
        XCTAssertNotNil(mockPersistence.savedUsers[user.id]?.lastLoginAt)
    }
    
    // MARK: - Delete Tests
    
    func test_delete_shouldRemoveFromBothLocalAndRemote() async throws {
        // Given
        let userId = UUID()
        let user = User(
            id: userId,
            email: "delete@example.com",
            firstName: "Delete",
            lastName: "Me"
        )
        
        mockPersistence.savedUsers[userId] = user
        mockAPIClient.mockResponse = VoidResponse()
        
        // When
        try await sut.delete(userId)
        
        // Then
        XCTAssertNil(mockPersistence.savedUsers[userId])
        XCTAssertTrue(mockAPIClient.deleteCalled)
    }
}

// MARK: - Mock Classes

private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var mockResponse: Any?
    var mockError: Error?
    var shouldFail = false
    
    var getCalled = false
    var postCalled = false
    var putCalled = false
    var deleteCalled = false
    
    func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T {
        getCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        postCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        putCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        deleteCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
        return mockResponse as! T
    }
    
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        deleteCalled = true
        if shouldFail {
            throw mockError ?? APIError.unknown
        }
    }
}

private final class MockPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    var savedUsers: [UUID: User] = [:]
    
    func save<T>(_ object: T) async throws where T: Identifiable {
        if let user = object as? User {
            savedUsers[user.id] = user
        }
    }
    
    func fetch<T>(_ id: T.ID) async throws -> T? where T: Identifiable {
        return savedUsers[id as! UUID] as? T
    }
    
    func delete<T>(type: T.Type, id: T.ID) async throws where T: Identifiable {
        savedUsers.removeValue(forKey: id as! UUID)
    }
    
    func fetchAll<T>() async throws -> [T] where T: Identifiable {
        return savedUsers.values.compactMap { $0 as? T }
    }
}

private struct VoidResponse: Codable {}

private enum APIError: Error {
    case networkError
    case unknown
}
