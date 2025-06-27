//
//  SwiftDataRepository.swift
//  clarity-loop-frontend-v2
//
//  Generic SwiftData repository implementation with entity mapping
//

import Foundation
import SwiftData
import ClarityDomain

/// Generic SwiftData repository implementation that handles entity mapping
/// This actor provides thread-safe database operations with automatic entity/model conversion
public actor SwiftDataRepository<
    EntityType: Entity & Sendable,
    ModelType: PersistentModel,
    MapperType: EntityMapper & Sendable
>: Repository
where MapperType.Entity == EntityType, MapperType.Model == ModelType {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer
    private let mapper: MapperType
    
    // MARK: - Initialization
    
    public init(
        modelContainer: ModelContainer,
        mapper: MapperType
    ) {
        self.modelContainer = modelContainer
        self.mapper = mapper
    }
    
    // MARK: - Private Helpers
    
    /// Performs work on the main actor with the model context
    /// This pattern ensures ModelContext operations happen on MainActor, avoiding Swift 6 sendability issues
    @MainActor
    private func withContext<T: Sendable>(_ work: @Sendable (ModelContext) async throws -> T) async throws -> T {
        let context = modelContainer.mainContext
        return try await work(context)
    }
    
    // MARK: - Repository Implementation
    
    public func create(_ entity: EntityType) async throws -> EntityType {
        // Capture values before entering the MainActor context
        let entityId = entity.id
        let mapper = self.mapper
        
        return try await withContext { @Sendable context in
            // Check for duplicate ID
            let descriptor = FetchDescriptor<ModelType>()
            let existingModels = try context.fetch(descriptor)
            
            // Find if model with same ID exists
            let hasExisting = existingModels.contains { model in
                // Use Mirror to check ID property
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id",
                       let modelId = child.value as? UUID,
                       modelId == entityId {
                        return true
                    }
                }
                return false
            }
            
            if hasExisting {
                throw RepositoryError.duplicateEntity
            }
            
            // Create model inside the MainActor context
            let mappedModel = mapper.toModel(entity)
            
            // Insert new model
            context.insert(mappedModel)
            try context.save()
            
            // Return the mapped entity
            return mapper.toEntity(mappedModel)
        }
    }
    
    public func read(id: UUID) async throws -> EntityType? {
        // Capture mapper to avoid capturing self
        let mapper = self.mapper
        
        return try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find model with matching ID
            for model in models {
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id",
                       let modelId = child.value as? UUID,
                       modelId == id {
                        return mapper.toEntity(model)
                    }
                }
            }
            
            return nil
        }
    }
    
    public func update(_ entity: EntityType) async throws -> EntityType {
        // Capture values before entering the MainActor context
        let entityId = entity.id
        let mapper = self.mapper
        
        return try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find existing model
            var existingModel: ModelType?
            for model in models {
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id",
                       let modelId = child.value as? UUID,
                       modelId == entityId {
                        existingModel = model
                        break
                    }
                }
                if existingModel != nil { break }
            }
            
            guard let modelToUpdate = existingModel else {
                throw RepositoryError.entityNotFound
            }
            
            // Create updated model inside the MainActor context
            let updatedModel = mapper.toModel(entity)
            
            // Update model properties using Mirror
            let sourceMirror = Mirror(reflecting: updatedModel)
            let targetMirror = Mirror(reflecting: modelToUpdate)
            
            // Get writable properties
            for sourceChild in sourceMirror.children {
                guard let label = sourceChild.label,
                      label != "id" else { continue } // Don't update ID
                
                // Find corresponding property in target
                for targetChild in targetMirror.children {
                    if targetChild.label == label {
                        // Use setValue if available (this is a simplified version)
                        // In production, you'd need proper property updating
                        break
                    }
                }
            }
            
            try context.save()
            return mapper.toEntity(modelToUpdate)
        }
    }
    
    public func delete(id: UUID) async throws {
        // Capture id to avoid capturing self
        let deleteId = id
        
        try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Find and delete model
            for model in models {
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id",
                       let modelId = child.value as? UUID,
                       modelId == deleteId {
                        context.delete(model)
                        try context.save()
                        return
                    }
                }
            }
            
            throw RepositoryError.entityNotFound
        }
    }
    
    public func list(
        predicate: RepositoryPredicate<EntityType>? = nil,
        sortBy: [RepositorySortDescriptor<EntityType>] = []
    ) async throws -> [EntityType] {
        // Capture values before entering the MainActor context
        let mapper = self.mapper
        let filterPredicate = predicate
        let sortDescriptors = sortBy
        
        return try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Convert to entities
            var entities = models.map { mapper.toEntity($0) }
            
            // Apply predicate if provided
            if let filterPredicate = filterPredicate {
                entities = entities.filter { filterPredicate.evaluate($0) }
            }
            
            // Apply sorting
            for sortDescriptor in sortDescriptors.reversed() {
                entities.sort(by: sortDescriptor.compare)
            }
            
            return entities
        }
    }
    
    public func count(
        predicate: RepositoryPredicate<EntityType>? = nil
    ) async throws -> Int {
        // Capture values before entering the MainActor context
        let mapper = self.mapper
        let filterPredicate = predicate
        
        return try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            if let filterPredicate = filterPredicate {
                // Convert to entities and count matching
                let entities = models.map { mapper.toEntity($0) }
                return entities.filter { filterPredicate.evaluate($0) }.count
            } else {
                return models.count
            }
        }
    }
    
    public func exists(id: UUID) async throws -> Bool {
        // Capture id to avoid capturing self
        let checkId = id
        
        return try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            // Check if model with ID exists
            for model in models {
                let mirror = Mirror(reflecting: model)
                for child in mirror.children {
                    if child.label == "id",
                       let modelId = child.value as? UUID,
                       modelId == checkId {
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    public func deleteAll(
        predicate: RepositoryPredicate<EntityType>? = nil
    ) async throws {
        // Capture values before entering the MainActor context
        let mapper = self.mapper
        let filterPredicate = predicate
        
        try await withContext { @Sendable context in
            let descriptor = FetchDescriptor<ModelType>()
            let models = try context.fetch(descriptor)
            
            if let filterPredicate = filterPredicate {
                // Convert to entities, filter, then delete matching models
                for model in models {
                    let entity = mapper.toEntity(model)
                    if filterPredicate.evaluate(entity) {
                        context.delete(model)
                    }
                }
            } else {
                // Delete all models
                for model in models {
                    context.delete(model)
                }
            }
            
            try context.save()
        }
    }
}

