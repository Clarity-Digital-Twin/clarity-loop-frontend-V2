//
//  ClarityPulseApp.swift
//  ClarityPulse
//
//  Created on 2025-06-25.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct ClarityPulseApp: App {
    // MARK: - Properties
    
    /// SwiftData model container
    private let modelContainer: ModelContainer
    
    /// Dependency injection container
    private let dependencies: DependencyContainer
    
    // MARK: - Initialization
    
    init() {
        // Initialize ModelContainer
        do {
            let schema = Schema([
                // Add model types here as we create them
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Initialize dependencies
        self.dependencies = DependencyContainer()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.dependencies, dependencies)
        }
    }
}

// MARK: - Dependency Container

/// Container for dependency injection
final class DependencyContainer: @unchecked Sendable {
    // Services will be added here as we implement them
    // @unchecked is safe here as we'll manage thread safety internally
}

// MARK: - Environment Keys

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}