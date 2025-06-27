//
//  SwiftDataRepository.swift
//  clarity-loop-frontend-v2
//
//  Generic SwiftData repository implementation with Swift 6 concurrency support
//  Uses MainActor pattern to handle ModelContext sendability issues
//

import Foundation
import SwiftData
@preconcurrency import ClarityDomain

/// Generic SwiftData implementation of the Repository protocol
/// Uses Swift 6 MainActor pattern for ModelContext operations
public actor SwiftDataRepository<EntityType: Entity & Sendable, ModelType: PersistentModel, MapperType: EntityMapper & Sendable>: Repository
where MapperType.Entity == EntityType, MapperType.Model == ModelType {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer  // ModelContainer is Sendable
    private let modelType: ModelType.Type
    private let mapper: MapperType  // Mapper must be Sendable
    
    // MARK: - Initialization
    
    /// Creates a new SwiftData repository
    /// - Parameters:
    ///   - modelContainer: The SwiftData model container
    ///   - modelType: The SwiftData model type
    ///   - mapper: The entity mapper for conversions
    public init(
        modelContainer: ModelContainer,
        modelType: ModelType.Type,
        mapper: MapperType
    ) {
        self.modelContainer = modelContainer
        self.modelType = modelType
        self.mapper = mapper
    }
    
    // MARK: - Private Helpers
    
    /// Performs synchronous work on the main actor with the model context
    /// This pattern ensures ModelContext operations happen on MainActor, avoiding Swift 6 sendability issues
    @MainActor
    private func performOperation<T>(_ operation: (ModelContext) throws -> T) async throws -> T {
        let context = modelContainer.mainContext
        return try operation(context)
    }
    
    /// Performs asynchronous work on the main actor with the model context
    @MainActor
    private func performAsyncOperation<T: Sendable>(_ operation: @Sendable (ModelContext) async throws -> T) async throws -> T {
        let context = modelContainer.mainContext
        return try await operation(context)
    }
    
    // MARK: - Repository Implementation
    
    public func create(_ entity: EntityType) async throws -> EntityType {
        return try await performOperation { context in
            // Check for duplicate ID
            let descriptor = FetchDescriptor<ModelType>()
            let existingModels = try context.fetch(descriptor)
            
            // Find if model with same ID exists
            let entityId = entity.id
            let hasExisting = existingModels.contains { model in
                // Use Mirror to check ID property
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id", let id = child.value as? UUID {
                        return id == entityId
                    }
                }
                return false
            }
            
            if hasExisting {
                throw RepositoryError.saveFailed("Entity with ID already exists")
            }
            
            // Create and insert new model
            let model = mapper.toModel(entity)
            context.insert(model)
            
            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed(error.localizedDescription)
            }
            
            // Map back to entity
            return mapper.toEntity(model)
        }
    }
    
    public func read(id: UUID) async throws -> EntityType? {
        return try await performOperation { context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find model with matching ID
            let matchingModel = models.first { model in
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id", let modelId = child.value as? UUID {
                        return modelId == id
                    }
                }
                return false
            }
            
            guard let model = matchingModel else {
                return nil
            }
            
            return mapper.toEntity(model)
        }
    }
    
    public func update(_ entity: EntityType) async throws -> EntityType {
        return try await performOperation { context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find existing model
            let entityId = entity.id
            let existingModel = models.first { model in
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id", let id = child.value as? UUID {
                        return id == entityId
                    }
                }
                return false
            }
            
            guard let modelToUpdate = existingModel else {
                throw RepositoryError.notFound
            }
            
            // Update model properties
            let updatedModel = mapper.toModel(entity)
            
            // Copy properties from updated model to existing model
            let sourceMirror = Mirror(reflecting: updatedModel)
            let targetMirror = Mirror(reflecting: modelToUpdate)
            
            for sourceChild in sourceMirror.children {
                guard let label = sourceChild.label else { continue }
                
                // Find corresponding property in target
                for targetChild in targetMirror.children {
                    if targetChild.label == label {
                        // Use setValue to update the property
                        (modelToUpdate as AnyObject).setValue(sourceChild.value, forKey: label)
                        break
                    }
                }
            }
            
            do {
                try context.save()
            } catch {
                throw RepositoryError.updateFailed(error.localizedDescription)
            }
            
            return mapper.toEntity(modelToUpdate)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await performOperation { context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find model to delete
            let modelToDelete = models.first { model in
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id", let modelId = child.value as? UUID {
                        return modelId == id
                    }
                }
                return false
            }
            
            guard let model = modelToDelete else {
                throw RepositoryError.notFound
            }
            
            context.delete(model)
            
            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }
    
    public func list(
        predicate: RepositoryPredicate<EntityType>? = nil,
        sortBy: [RepositorySortDescriptor<EntityType>] = []
    ) async throws -> [EntityType] {
        return try await performOperation { context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Map models to entities
            var entities: [EntityType] = []
            for model in models {
                entities.append(mapper.toEntity(model))
            }
            
            // Apply predicate if provided
            if let predicate = predicate {
                entities = entities.filter { predicate.evaluate($0) }
            }
            
            // Apply sorting
            for descriptor in sortBy.reversed() {
                entities.sort { descriptor.compare($0, $1) }
            }
            
            return entities
        }
    }
    
    public func count(predicate: RepositoryPredicate<EntityType>? = nil) async throws -> Int {
        let entities = try await list(predicate: predicate)
        return entities.count
    }
    
    public func deleteAll(predicate: RepositoryPredicate<EntityType>? = nil) async throws {
        // Handle the predicate filtering outside the MainActor context
        let idsToDelete: [UUID]? = if let predicate = predicate {
            try await list(predicate: predicate).map { $0.id }
        } else {
            nil
        }
        
        try await performOperation { context in
            if let idsToDelete = idsToDelete {
                // Delete specific models
                let descriptor = FetchDescriptor<ModelType>()
                let models = try context.fetch(descriptor)
                
                for model in models {
                    let mirror = Mirror(reflecting: model)
                    for child in mirror.children {
                        if child.label == "id", let modelId = child.value as? UUID {
                            if idsToDelete.contains(modelId) {
                                context.delete(model)
                            }
                            break
                        }
                    }
                }
            } else {
                // Delete all
                let descriptor = FetchDescriptor<ModelType>()
                let models = try context.fetch(descriptor)
                
                for model in models {
                    context.delete(model)
                }
            }
            
            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }
    
    /// Executes operations within a transaction
    public func transaction(_ operation: @escaping (SwiftDataRepository<EntityType, ModelType, MapperType>) async throws -> Void) async throws {
        // Execute the operation - SwiftData handles transactions automatically with context.save()
        try await operation(self)
    }
}

// MARK: - SwiftData Repository Error

/// Errors specific to SwiftData repository operations
public enum SwiftDataRepositoryError: Error, Sendable {
    case contextUnavailable
    case mappingFailed
    case entityNotFound
    case invalidIdentifier
    case modelConversionFailed
    
    var localizedDescription: String {
        switch self {
        case .contextUnavailable:
            return "SwiftData model context is unavailable"
        case .mappingFailed:
            return "Failed to map between entity and model"
        case .entityNotFound:
            return "Entity not found in repository"
        case .invalidIdentifier:
            return "Invalid identifier type for repository operation"
        case .modelConversionFailed:
            return "Failed to convert between model types"
        }
    }
}