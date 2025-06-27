//
//  EntityMapper.swift
//  clarity-loop-frontend-v2
//
//  Protocol for mapping between domain entities and SwiftData models
//

import Foundation

/// Protocol for mapping between domain entities and persistence models
/// Conforming types must be Sendable for Swift 6 concurrency compliance
public protocol EntityMapper: Sendable {
    /// The domain entity type
    associatedtype Entity
    
    /// The SwiftData model type
    associatedtype Model
    
    /// Converts a domain entity to a SwiftData model
    /// - Parameter entity: The domain entity to convert
    /// - Returns: The corresponding SwiftData model
    func toModel(_ entity: Entity) -> Model
    
    /// Converts a SwiftData model to a domain entity
    /// - Parameter model: The SwiftData model to convert
    /// - Returns: The corresponding domain entity
    func toEntity(_ model: Model) -> Entity
}