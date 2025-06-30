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
        modifier(ModelContainerModifier(factory: factory))
    }
    
    /// Adds a test model container to the SwiftUI environment
    func withTestModelContainer(_ factory: ModelContainerFactory = ModelContainerFactory()) -> some View {
        modifier(TestModelContainerModifier(factory: factory))
    }
}

// MARK: - ViewModifiers

private struct ModelContainerModifier: ViewModifier {
    let factory: ModelContainerFactory
    @State private var containerState: ContainerState = .loading
    
    enum ContainerState {
        case loading
        case loaded(ModelContainer)
        case failed(Error)
    }
    
    func body(content: Content) -> some View {
        Group {
            switch containerState {
            case .loading:
                ProgressView("Loading data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let container):
                content
                    .modelContainer(container)
            case .failed(let error):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load data")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadContainer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            loadContainer()
        }
    }
    
    private func loadContainer() {
        containerState = .loading
        Task {
            do {
                let container = try factory.createContainer()
                await MainActor.run {
                    containerState = .loaded(container)
                }
            } catch {
                await MainActor.run {
                    containerState = .failed(error)
                }
            }
        }
    }
}

private struct TestModelContainerModifier: ViewModifier {
    let factory: ModelContainerFactory
    @State private var containerState: ContainerState = .loading
    
    enum ContainerState {
        case loading
        case loaded(ModelContainer)
        case failed(Error)
    }
    
    func body(content: Content) -> some View {
        Group {
            switch containerState {
            case .loading:
                Color.clear
                    .onAppear {
                        loadContainer()
                    }
            case .loaded(let container):
                content
                    .modelContainer(container)
            case .failed:
                // For tests, just show empty content on failure
                content
            }
        }
    }
    
    private func loadContainer() {
        containerState = .loading
        Task {
            do {
                let container = try factory.createInMemoryContainer()
                await MainActor.run {
                    containerState = .loaded(container)
                }
            } catch {
                await MainActor.run {
                    containerState = .failed(error)
                }
            }
        }
    }
}
