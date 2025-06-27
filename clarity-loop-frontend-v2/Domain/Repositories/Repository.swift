//
//  Repository.swift
//  clarity-loop-frontend-v2
//
//  Generic Repository protocol with CRUD operations
//

import Foundation

/// Generic repository protocol for entity persistence
/// Follows the Repository pattern from Domain-Driven Design
public protocol Repository: Actor {
    /// The type of entity this repository manages
    associatedtype EntityType: Entity
    
    // MARK: - Create
    
    /// Creates a new entity in the repository
    /// - Parameter entity: The entity to create
    /// - Returns: The created entity (may include server-generated fields)
    /// - Throws: RepositoryError if creation fails
    func create(_ entity: EntityType) async throws -> EntityType
    
    // MARK: - Read
    
    /// Reads an entity by its identifier
    /// - Parameter id: The unique identifier of the entity
    /// - Returns: The entity if found, nil otherwise
    /// - Throws: RepositoryError if the read operation fails
    func read(id: UUID) async throws -> EntityType?
    
    // MARK: - Update
    
    /// Updates an existing entity
    /// - Parameter entity: The entity with updated values
    /// - Returns: The updated entity
    /// - Throws: RepositoryError if update fails or entity doesn't exist
    func update(_ entity: EntityType) async throws -> EntityType
    
    // MARK: - Delete
    
    /// Deletes an entity by its identifier
    /// - Parameter id: The unique identifier of the entity to delete
    /// - Throws: RepositoryError if deletion fails or entity doesn't exist
    func delete(id: UUID) async throws
    
    // MARK: - Query Operations
    
    /// Lists entities matching optional criteria
    /// - Parameters:
    ///   - predicate: Optional predicate to filter results
    ///   - sortBy: Array of sort descriptors to order results
    /// - Returns: Array of entities matching the criteria
    /// - Throws: RepositoryError if the query fails
    func list(
        predicate: RepositoryPredicate<EntityType>?,
        sortBy: [RepositorySortDescriptor<EntityType>]
    ) async throws -> [EntityType]
    
    /// Counts entities matching optional criteria
    /// - Parameter predicate: Optional predicate to filter counted entities
    /// - Returns: The count of matching entities
    /// - Throws: RepositoryError if the count operation fails
    func count(predicate: RepositoryPredicate<EntityType>?) async throws -> Int
    
    /// Deletes all entities matching optional criteria
    /// - Parameter predicate: Optional predicate to filter entities to delete
    /// - Throws: RepositoryError if the delete operation fails
    func deleteAll(predicate: RepositoryPredicate<EntityType>?) async throws
}

// MARK: - Default Implementations

public extension Repository {
    /// Lists all entities without filtering or sorting
    func list() async throws -> [EntityType] {
        try await list(predicate: nil, sortBy: [])
    }
    
    /// Lists entities with filtering but no sorting
    func list(predicate: RepositoryPredicate<EntityType>?) async throws -> [EntityType] {
        try await list(predicate: predicate, sortBy: [])
    }
    
    /// Lists entities with sorting but no filtering
    func list(sortBy: [RepositorySortDescriptor<EntityType>]) async throws -> [EntityType] {
        try await list(predicate: nil, sortBy: sortBy)
    }
    
    /// Counts all entities without filtering
    func count() async throws -> Int {
        try await count(predicate: nil)
    }
    
    /// Deletes all entities without filtering
    func deleteAll() async throws {
        try await deleteAll(predicate: nil)
    }
}

// MARK: - Query Support Types

/// Type-safe predicate for filtering entities
public struct RepositoryPredicate<T> {
    /// The evaluation closure
    public let evaluate: (T) -> Bool
    
    /// Creates a new predicate with the given evaluation closure
    /// - Parameter evaluate: Closure that returns true for matching entities
    public init(_ evaluate: @escaping (T) -> Bool) {
        self.evaluate = evaluate
    }
}

/// Type-safe sort descriptor for ordering entities
public struct RepositorySortDescriptor<T> {
    /// The comparison closure
    public let compare: (T, T) -> Bool
    
    /// Creates a sort descriptor for a comparable property
    /// - Parameters:
    ///   - keyPath: Key path to the property to sort by
    ///   - ascending: Whether to sort in ascending order (default: true)
    public init<Value: Comparable>(
        keyPath: KeyPath<T, Value>,
        ascending: Bool = true
    ) {
        self.compare = { lhs, rhs in
            let lhsValue = lhs[keyPath: keyPath]
            let rhsValue = rhs[keyPath: keyPath]
            return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
        }
    }
}


// MARK: - Usage Documentation

/**
 Repository Pattern Implementation Guide
 =====================================
 
 The Repository pattern provides an abstraction layer between domain logic
 and data persistence. It encapsulates storage, retrieval, and search behavior.
 
 ## Creating a Repository Implementation
 
 ```swift
 actor UserRepository: Repository {
     typealias EntityType = User
     
     private let apiClient: APIClientProtocol
     private let persistence: PersistenceServiceProtocol
     
     func create(_ entity: User) async throws -> User {
         // 1. Validate entity
         // 2. Save to backend API
         // 3. Cache locally
         // 4. Return saved entity
     }
     
     // ... implement other required methods
 }
 ```
 
 ## Using Predicates
 
 ```swift
 // Find active users
 let activePredicate = RepositoryPredicate<User> { $0.isActive }
 let activeUsers = try await repository.list(predicate: activePredicate)
 
 // Find users by email domain
 let domainPredicate = RepositoryPredicate<User> { user in
     user.email.hasSuffix("@company.com")
 }
 ```
 
 ## Using Sort Descriptors
 
 ```swift
 // Sort by creation date, newest first
 let dateSort = RepositorySortDescriptor<User>(keyPath: \.createdAt, ascending: false)
 
 // Sort by name alphabetically
 let nameSort = RepositorySortDescriptor<User>(keyPath: \.lastName, ascending: true)
 
 // Multiple sort criteria
 let users = try await repository.list(sortBy: [nameSort, dateSort])
 ```
 
 ## Error Handling
 
 ```swift
 do {
     let user = try await repository.read(id: userId)
 } catch RepositoryError.notFound {
     // Handle missing entity
 } catch RepositoryError.networkError(let message) {
     // Handle network issues
 } catch {
     // Handle other errors
 }
 ```
 
 ## Best Practices
 
 1. **Keep repositories focused**: One repository per aggregate root
 2. **Use actors**: Ensure thread-safety with Swift's actor model
 3. **Handle offline**: Implement local caching for offline support
 4. **Validate entities**: Check business rules before persisting
 5. **Use transactions**: Group related operations when possible
 */