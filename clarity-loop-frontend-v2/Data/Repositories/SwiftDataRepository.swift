//
//  SwiftDataRepository.swift
//  clarity-loop-frontend-v2
//
//  Generic SwiftData repository implementation
//

import Foundation
import SwiftData
@preconcurrency import ClarityDomain

/// Generic SwiftData implementation of the Repository protocol
public actor SwiftDataRepository<EntityType: Entity, ModelType: PersistentModel, MapperType: EntityMapper>
where MapperType.Entity == EntityType, MapperType.Model == ModelType {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer
    private let modelType: ModelType.Type
    private let mapper: MapperType
    
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
    
    /// Gets a new model context for operations
    @MainActor
    private func getContext() -> ModelContext {
        modelContainer.mainContext
    }
}

// MARK: - Repository Implementation

extension SwiftDataRepository: Repository {
    
    public func create(_ entity: EntityType) async throws -> EntityType {
        let context = await getContext()
        
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
    
    public func read(id: UUID) async throws -> EntityType? {
        let context = await getContext()
        
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
    
    public func update(_ entity: EntityType) async throws -> EntityType {
        let context = await getContext()
        
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
    
    public func delete(id: UUID) async throws {
        let context = await getContext()
        
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
    
    public func list(
        predicate: RepositoryPredicate<EntityType>? = nil,
        sortBy: [RepositorySortDescriptor<EntityType>] = []
    ) async throws -> [EntityType] {
        let context = await getContext()
        
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
    
    public func count(predicate: RepositoryPredicate<EntityType>? = nil) async throws -> Int {
        let entities = try await list(predicate: predicate)
        return entities.count
    }
    
    public func deleteAll(predicate: RepositoryPredicate<EntityType>? = nil) async throws {
        let context = await getContext()
        
        if let predicate = predicate {
            // Fetch and filter
            let entitiesToDelete = try await list(predicate: predicate)
            let idsToDelete = entitiesToDelete.map { $0.id }
            
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
    
    /// Executes operations within a transaction
    public func transaction(_ operation: @escaping (SwiftDataRepository<EntityType, ModelType, MapperType>) async throws -> Void) async throws {
        // Create a transaction context
        let transactionContext = await getContext()
        
        // Save original state
        let hasChanges = transactionContext.hasChanges
        
        do {
            // Execute the operation
            try await operation(self)
            
            // Commit transaction
            try transactionContext.save()
        } catch {
            // Rollback on error
            if !hasChanges {
                transactionContext.rollback()
            }
            throw error
        }
    }
}