//
//  SwiftDataPersistence.swift
//  clarity-loop-frontend-v2
//
//  SwiftData persistence implementation for local storage
//

import Foundation
import SwiftData
import ClarityDomain

/// SwiftData persistence implementation
public final class SwiftDataPersistence: Sendable {
    
    private let container: ModelContainer
    
    public init(container: ModelContainer) {
        self.container = container
    }
    
    public func save<T: Identifiable>(_ object: T) async throws {
        let context = ModelContext(container)
        
        // Convert domain model to persisted model
        if let user = object as? User {
            let persistedUser = PersistedUser(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                createdAt: user.createdAt,
                lastLoginAt: user.lastLoginAt,
                dateOfBirth: user.dateOfBirth,
                phoneNumber: user.phoneNumber
            )
            context.insert(persistedUser)
            
        } else if let metric = object as? HealthMetric {
            let persistedMetric = PersistedHealthMetric(
                id: metric.id,
                userId: metric.userId,
                type: metric.type.rawValue,
                value: metric.value,
                unit: metric.unit,
                recordedAt: metric.recordedAt
            )
            persistedMetric.source = metric.source?.rawValue
            persistedMetric.notes = metric.notes
            context.insert(persistedMetric)
            
        } else {
            throw PersistenceError.unsupportedType
        }
        
        try context.save()
    }
    
    public func fetch<T: Identifiable>(_ id: T.ID) async throws -> T? {
        guard let uuid = id as? UUID else { return nil }
        return try await fetchById(type: T.self, id: uuid)
    }
    
    private func fetchById<T: Identifiable>(type: T.Type, id: UUID) async throws -> T? {
        let context = ModelContext(container)
        
        if T.self == User.self {
            let descriptor = FetchDescriptor<PersistedUser>(
                predicate: #Predicate { $0.id == id }
            )
            
            let results = try context.fetch(descriptor)
            guard let persistedUser = results.first else { return nil }
            
            return User(
                id: persistedUser.id,
                email: persistedUser.email,
                firstName: persistedUser.firstName,
                lastName: persistedUser.lastName,
                createdAt: persistedUser.createdAt,
                lastLoginAt: persistedUser.lastLoginAt,
                dateOfBirth: persistedUser.dateOfBirth,
                phoneNumber: persistedUser.phoneNumber
            ) as? T
            
        } else if T.self == HealthMetric.self {
            let descriptor = FetchDescriptor<PersistedHealthMetric>(
                predicate: #Predicate { $0.id == id }
            )
            
            let results = try context.fetch(descriptor)
            guard let persistedMetric = results.first else { return nil }
            
            let source = persistedMetric.source.flatMap { HealthMetricSource(rawValue: $0) }
            
            return HealthMetric(
                id: persistedMetric.id,
                userId: persistedMetric.userId,
                type: HealthMetricType(rawValue: persistedMetric.type) ?? .custom(persistedMetric.type),
                value: persistedMetric.value,
                unit: persistedMetric.unit,
                recordedAt: persistedMetric.recordedAt,
                source: source,
                notes: persistedMetric.notes
            ) as? T
        }
        
        return nil
    }
    
    public func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        guard let uuid = id as? UUID else { return }
        try await deleteById(type: type, id: uuid)
    }
    
    private func deleteById<T: Identifiable>(type: T.Type, id: UUID) async throws {
        let context = ModelContext(container)
        
        if T.self == User.self {
            let descriptor = FetchDescriptor<PersistedUser>(
                predicate: #Predicate { $0.id == id }
            )
            
            let results = try context.fetch(descriptor)
            if let user = results.first {
                context.delete(user)
                try context.save()
            }
            
        } else if T.self == HealthMetric.self {
            let descriptor = FetchDescriptor<PersistedHealthMetric>(
                predicate: #Predicate { $0.id == id }
            )
            
            let results = try context.fetch(descriptor)
            if let metric = results.first {
                context.delete(metric)
                try context.save()
            }
        }
    }
    
    public func fetchAll<T: Identifiable>() async throws -> [T] {
        let context = ModelContext(container)
        
        if T.self == User.self {
            let descriptor = FetchDescriptor<PersistedUser>()
            let results = try context.fetch(descriptor)
            
            return results.map { persistedUser in
                User(
                    id: persistedUser.id,
                    email: persistedUser.email,
                    firstName: persistedUser.firstName,
                    lastName: persistedUser.lastName,
                    createdAt: persistedUser.createdAt,
                    lastLoginAt: persistedUser.lastLoginAt,
                    dateOfBirth: persistedUser.dateOfBirth,
                    phoneNumber: persistedUser.phoneNumber
                )
            } as? [T] ?? []
            
        } else if T.self == HealthMetric.self {
            let descriptor = FetchDescriptor<PersistedHealthMetric>()
            let results = try context.fetch(descriptor)
            
            return results.map { persistedMetric in
                let source = persistedMetric.source.flatMap { HealthMetricSource(rawValue: $0) }
                
                return HealthMetric(
                    id: persistedMetric.id,
                    userId: persistedMetric.userId,
                    type: HealthMetricType(rawValue: persistedMetric.type) ?? .custom(persistedMetric.type),
                    value: persistedMetric.value,
                    unit: persistedMetric.unit,
                    recordedAt: persistedMetric.recordedAt,
                    source: source,
                    notes: persistedMetric.notes
                )
            } as? [T] ?? []
        }
        
        return []
    }
}

// MARK: - Conformance to PersistenceServiceProtocol

extension SwiftDataPersistence: PersistenceServiceProtocol {
    // The protocol conformance is satisfied by the methods above
}

// MARK: - Persistence Error

enum PersistenceError: LocalizedError {
    case unsupportedType
    case dataCorruption
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "The entity type is not supported for persistence"
        case .dataCorruption:
            return "Data integrity error occurred"
        case .notFound:
            return "Entity not found"
        }
    }
}
