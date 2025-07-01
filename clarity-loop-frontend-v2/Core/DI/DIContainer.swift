//
//  DIContainer.swift
//  clarity-loop-frontend-v2
//
//  Dependency Injection Container for managing app dependencies
//

import Foundation

/// Scope for dependency lifetime
public enum DIScope {
    case singleton
    case transient
}

/// Main Dependency Injection Container
public final class DIContainer: @unchecked Sendable {
    
    // MARK: - Types
    
    private struct ServiceKey: Hashable {
        let type: String
        
        init<T>(_ type: T.Type) {
            self.type = String(describing: type)
        }
    }
    
    private struct ServiceEntry {
        let scope: DIScope
        let factory: (DIContainer) -> Any
        var instance: Any?
    }
    
    // MARK: - Properties
    
    private var services: [ServiceKey: ServiceEntry] = [:]
    private let lock = NSLock()
    
    /// Expose registration count for debugging
    public var registrations: [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        var result: [String: Any] = [:]
        for (key, _) in services {
            result[key.type] = true
        }
        return result
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Registration
    
    /// Register a service with the container
    public func register<T>(
        _ type: T.Type,
        scope: DIScope = .singleton,
        factory: @escaping (DIContainer) -> T
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        services[key] = ServiceEntry(
            scope: scope,
            factory: factory,
            instance: nil
        )
    }
    
    // MARK: - Resolution
    
    /// Resolve a service from the container
    public func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ServiceKey(type)
        guard var entry = services[key] else {
            return nil
        }
        
        switch entry.scope {
        case .singleton:
            if let instance = entry.instance as? T {
                return instance
            }
            let instance = entry.factory(self) as! T
            entry.instance = instance
            services[key] = entry
            return instance
            
        case .transient:
            return entry.factory(self) as? T
        }
    }
    
    /// Resolve a required service (crashes if not found)
    public func require<T>(_ type: T.Type) -> T {
        guard let service = resolve(type) else {
            let typeName = String(describing: type)
            preconditionFailure(
                """
                🚨 Dependency Injection Error
                
                Service of type '\(typeName)' is not registered in the DI container.
                
                This is a configuration error that should be caught during development.
                Please ensure AppDependencies.configure() is called and includes this service.
                
                Registered services: \(services.keys.map { $0.type }.sorted())
                """
            )
        }
        return service
    }
}

// MARK: - Shared Container

public extension DIContainer {
    /// Shared container instance
    static let shared = DIContainer()
}
