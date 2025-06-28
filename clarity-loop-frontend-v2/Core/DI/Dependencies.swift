//
//  Dependencies.swift
//  clarity-loop-frontend-v2
//
//  SwiftUI Environment-based Dependency Injection Container
//

import Foundation
import SwiftUI

/// Thread-safe dependency container for SwiftUI Environment
public final class Dependencies: ObservableObject {
    
    // MARK: - Types
    
    private struct ServiceKey: Hashable {
        let type: String
        
        init<T>(_ type: T.Type) {
            self.type = String(describing: type)
        }
    }
    
    private enum ServiceEntry {
        case instance(Any)
        case factory(() -> Any)
        case factoryWithContainer((Dependencies) -> Any)
    }
    
    // MARK: - Properties
    
    private var services: [ServiceKey: ServiceEntry] = [:]
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Registration
    
    /// Register a service instance
    public func register<T>(_ type: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        services[key] = .instance(instance)
    }
    
    /// Register a service factory
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        services[key] = .factory(factory)
    }
    
    /// Register a service factory with container access
    public func register<T>(_ type: T.Type, factory: @escaping (Dependencies) -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        services[key] = .factoryWithContainer(factory)
    }
    
    // MARK: - Resolution
    
    /// Resolve a service from the container
    public func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        guard let entry = services[key] else {
            return nil
        }
        
        switch entry {
        case .instance(let instance):
            return instance as? T
            
        case .factory(let factory):
            return factory() as? T
            
        case .factoryWithContainer(let factory):
            return factory(self) as? T
        }
    }
    
    /// Resolve a required service (crashes if not found)
    public func require<T>(_ type: T.Type) -> T {
        guard let service = resolve(type) else {
            fatalError("❌ Service of type \(type) is not registered in Dependencies container")
        }
        return service
    }
    
    // MARK: - Mock Support
    
    /// Create a mock container for testing
    public static func mock(configure: (Dependencies) -> Void) -> Dependencies {
        let container = Dependencies()
        configure(container)
        return container
    }
}

// MARK: - Environment Key

public struct DependenciesKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue = Dependencies()
}

// MARK: - Environment Values Extension

public extension EnvironmentValues {
    var dependencies: Dependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Inject dependencies into the SwiftUI environment
    func dependencies(_ dependencies: Dependencies) -> some View {
        self.environment(\.dependencies, dependencies)
    }
}

// MARK: - App Dependency Configurator

/// Configures all app dependencies
public struct AppDependencyConfigurator {
    
    public init() {}
    
    /// Configure all app dependencies
    public func configure(_ container: Dependencies) {
        // Note: These will be configured in AppDependencies.swift
        // This is just the structure for the configurator
    }
}
