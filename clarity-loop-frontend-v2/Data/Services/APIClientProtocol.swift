//
//  APIClientProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for API client implementations
//

import Foundation

/// Protocol defining API client operations
protocol APIClientProtocol: Sendable {
    /// Perform GET request
    func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T
    
    /// Perform POST request
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T
    
    /// Perform PUT request
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T
    
    /// Perform DELETE request
    func delete<T: Decodable>(_ endpoint: String) async throws -> T
    
    /// Perform DELETE request with type (for implementations like HealthMetricRepository)
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws
}

/// Protocol for persistence operations
protocol PersistenceServiceProtocol: Sendable {
    /// Save an object to local storage
    func save<T: Identifiable>(_ object: T) async throws
    
    /// Fetch an object by ID
    func fetch<T: Identifiable>(_ id: T.ID) async throws -> T?
    
    /// Delete an object by ID
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws
    
    /// Fetch all objects of a type
    func fetchAll<T: Identifiable>() async throws -> [T]
}