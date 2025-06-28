//
//  ModelContainerFactory.swift
//  clarity-loop-frontend-v2
//
//  Factory for creating SwiftData ModelContainer instances
//

import Foundation
import SwiftData

/// Factory for creating and configuring SwiftData ModelContainer instances
public final class ModelContainerFactory: @unchecked Sendable {
    
    // MARK: - Properties
    
    @MainActor
    private static var sharedContainer: ModelContainer?
    
    // MARK: - Schema Definition
    
    /// All model types that should be included in the container
    private var modelTypes: [any PersistentModel.Type] {
        [
            PersistedUser.self,
            PersistedHealthMetric.self
        ]
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Container Creation
    
    /// Creates the default model container for production use
    public func createContainer() throws -> ModelContainer {
        let configuration = defaultConfiguration()
        return try ModelContainer(
            for: Schema(modelTypes),
            configurations: [configuration]
        )
    }
    
    /// Creates an in-memory container for testing
    public func createInMemoryContainer() throws -> ModelContainer {
        let configuration = testConfiguration()
        return try ModelContainer(
            for: Schema(modelTypes),
            configurations: [configuration]
        )
    }
    
    /// Creates a container with CloudKit sync enabled
    public func createCloudContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(modelTypes),
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        return try ModelContainer(
            for: Schema(modelTypes),
            configurations: [configuration]
        )
    }
    
    // MARK: - Configuration
    
    /// Default configuration for production
    public func defaultConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: Schema(modelTypes),
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
    }
    
    /// Test configuration (in-memory)
    public func testConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: Schema(modelTypes),
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
    }
    
    // MARK: - Shared Container
    
    /// Returns a shared container instance (singleton pattern)
    @MainActor
    public func shared() throws -> ModelContainer {
        if let container = Self.sharedContainer {
            return container
        }
        
        let container = try createContainer()
        Self.sharedContainer = container
        return container
    }
    
    /// Resets the shared container (useful for testing)
    @MainActor
    public func resetShared() {
        Self.sharedContainer = nil
    }
    
    // MARK: - Migration Support
    
    /// Creates a container with migration support
    public func createContainerWithMigration(
        from oldSchema: Schema,
        to newSchema: Schema
    ) throws -> ModelContainer {
        // TODO: Implement migration plan when needed
        // For now, just create a regular container
        return try createContainer()
    }
}

// MARK: - SwiftUI Environment Support

import SwiftUI

public extension View {
    /// Adds the model container to the SwiftUI environment
    func withModelContainer(_ factory: ModelContainerFactory = ModelContainerFactory()) -> some View {
        do {
            let container = try factory.createContainer()
            return self.modelContainer(container)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    /// Adds a test model container to the SwiftUI environment
    func withTestModelContainer(_ factory: ModelContainerFactory = ModelContainerFactory()) -> some View {
        do {
            let container = try factory.createInMemoryContainer()
            return self.modelContainer(container)
        } catch {
            fatalError("Failed to create test model container: \(error)")
        }
    }
}
