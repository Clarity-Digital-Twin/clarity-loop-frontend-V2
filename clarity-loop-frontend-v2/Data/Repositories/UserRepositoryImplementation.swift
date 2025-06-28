//
//  UserRepositoryImplementation.swift
//  clarity-loop-frontend-v2
//
//  Concrete implementation of UserRepository
//

import Foundation
import ClarityDomain

/// Concrete implementation of UserRepositoryProtocol
public final class UserRepositoryImplementation: UserRepositoryProtocol {
    
    private let apiClient: APIClientProtocol
    private let persistence: PersistenceServiceProtocol
    
    public init(apiClient: APIClientProtocol, persistence: PersistenceServiceProtocol) {
        self.apiClient = apiClient
        self.persistence = persistence
    }
    
    public func create(_ user: User) async throws -> User {
        // Convert to DTO and send to API
        let dto = user.toDTO()
        let responseDTO: UserDTO = try await apiClient.post("/api/v1/users", body: dto)
        
        // Convert response back to domain model
        let createdUser = try responseDTO.toDomainModel()
        
        // Save to local persistence
        try await persistence.save(createdUser)
        
        return createdUser
    }
    
    public func findById(_ id: UUID) async throws -> User? {
        // First check local cache
        if let cachedUser: User = try await persistence.fetch(id) {
            return cachedUser
        }
        
        // If not found locally, fetch from API
        do {
            let dto: UserDTO = try await apiClient.get("/api/v1/users/\(id.uuidString)", parameters: nil)
            let user = try dto.toDomainModel()
            
            // Cache the result
            try await persistence.save(user)
            
            return user
        } catch {
            // If API returns 404, return nil instead of throwing
            return nil
        }
    }
    
    public func findByEmail(_ email: String) async throws -> User? {
        // Search API by email
        let parameters = ["email": email]
        
        do {
            let response: UserListResponse = try await apiClient.get("/api/v1/users", parameters: parameters)
            
            guard let firstUserDTO = response.users.first else {
                return nil
            }
            
            let user = try firstUserDTO.toDomainModel()
            
            // Cache the result
            try await persistence.save(user)
            
            return user
        } catch {
            return nil
        }
    }
    
    public func update(_ user: User) async throws -> User {
        // Update via API
        let dto = user.toDTO()
        let responseDTO: UserDTO = try await apiClient.put("/api/v1/users/\(user.id.uuidString)", body: dto)
        
        let updatedUser = try responseDTO.toDomainModel()
        
        // Update local cache
        try await persistence.save(updatedUser)
        
        return updatedUser
    }
    
    public func delete(_ id: UUID) async throws {
        // Delete from API
        let _: VoidResponse = try await apiClient.delete("/api/v1/users/\(id.uuidString)")
        
        // Remove from local cache
        try await persistence.delete(type: User.self, id: id)
    }
    
    public func findAll() async throws -> [User] {
        // For now, fetch from API
        // In a real app, might implement pagination
        let response: UserListResponse = try await apiClient.get("/api/v1/users", parameters: nil)
        
        let users = try response.users.map { try $0.toDomainModel() }
        
        // Cache all results
        for user in users {
            try await persistence.save(user)
        }
        
        return users
    }
}

// MARK: - Response Types

private struct UserListResponse: Codable {
    let users: [UserDTO]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case users = "data"
        case total
        case page
        case pageSize = "page_size"
    }
}

private struct VoidResponse: Codable {}
