//
//  Entity.swift
//  clarity-loop-frontend-v2
//
//  Base protocol for all domain entities
//

import Foundation

/// Base protocol for all domain entities in the CLARITY Pulse application
///
/// The `Entity` protocol defines the fundamental contract for all domain entities,
/// ensuring consistent behavior and properties across the domain layer. This protocol
/// follows Domain-Driven Design (DDD) principles and provides:
///
/// - **Unique Identification**: Every entity has a UUID for global uniqueness
/// - **Temporal Tracking**: Built-in creation and update timestamps
/// - **Type Safety**: Leverages Swift's type system with associated type constraints
/// - **Identifiable Conformance**: Automatic SwiftUI list compatibility
///
/// ## Usage Example
/// ```swift
/// struct User: Entity {
///     let id: UUID
///     let createdAt: Date
///     let updatedAt: Date
///     let email: String
///     let name: String
/// }
/// ```
///
/// ## Design Decisions
/// - Uses `UUID` for identifiers to ensure uniqueness across distributed systems
/// - Requires explicit timestamp properties for audit trail and synchronization
/// - Extends `Identifiable` for seamless SwiftUI integration
/// - All properties are read-only to encourage immutability
///
/// - Note: Entities should be immutable value types (structs) unless there's a
///   specific need for reference semantics
public protocol Entity: Identifiable where ID == UUID {
    /// Unique identifier for the entity
    ///
    /// This UUID serves as the primary key for the entity and ensures
    /// global uniqueness across all instances. It should be generated
    /// once during entity creation and never modified.
    var id: UUID { get }
    
    /// Timestamp when the entity was created
    ///
    /// Records the exact moment this entity came into existence.
    /// This value should be set once during initialization and remain
    /// immutable throughout the entity's lifecycle.
    var createdAt: Date { get }
    
    /// Timestamp when the entity was last updated
    ///
    /// Tracks the most recent modification to this entity.
    /// Initially set to the same value as `createdAt`, then updated
    /// whenever the entity's state changes.
    var updatedAt: Date { get }
}

// MARK: - Protocol Extensions

public extension Entity {
    /// Checks if two entities are equal based on their ID
    ///
    /// This method provides identity-based equality comparison, which is the
    /// fundamental way to determine if two entity instances represent the same
    /// domain object. This is particularly useful when comparing entities that
    /// may have different property values but represent the same logical entity.
    ///
    /// - Parameter other: Another entity to compare with
    /// - Returns: `true` if both entities have the same ID, `false` otherwise
    ///
    /// ## Example
    /// ```swift
    /// let user1 = User(id: uuid, email: "old@example.com", ...)
    /// let user2 = User(id: uuid, email: "new@example.com", ...)
    /// print(user1.isEqual(to: user2)) // true - same ID
    /// ```
    func isEqual(to other: Self) -> Bool {
        id == other.id
    }
    
    /// Indicates whether the entity has been updated after creation
    ///
    /// This computed property helps track whether an entity has undergone
    /// any modifications since its initial creation. Useful for:
    /// - Audit trails
    /// - Sync operations
    /// - UI indicators for modified data
    ///
    /// - Returns: `true` if `updatedAt` is later than `createdAt`
    var wasUpdated: Bool {
        updatedAt > createdAt
    }
}

// MARK: - Equatable Support

/// Provides default Equatable implementation for Entity types
///
/// When an entity conforms to `Equatable`, this extension provides a default
/// implementation that compares entities based solely on their ID. This ensures
/// consistent identity-based equality across all entities.
///
/// ## Design Rationale
/// Entity equality is based on identity, not value equality. Two entities with
/// the same ID are considered equal even if their other properties differ.
public extension Entity where Self: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable Support

/// Provides default Hashable implementation for Entity types
///
/// When an entity conforms to `Hashable`, this extension ensures that the hash
/// value is based solely on the entity's ID. This maintains consistency with the
/// Equatable implementation and enables entities to be used in Sets and as
/// Dictionary keys.
///
/// ## Important
/// Since hash is based only on ID, entities with the same ID will have the same
/// hash value, making them indistinguishable in hash-based collections.
public extension Entity where Self: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}