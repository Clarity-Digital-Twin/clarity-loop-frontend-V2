# Core Layer

The Core layer contains shared infrastructure and utilities used across all other layers. This includes the Dependency Injection container and other cross-cutting concerns.

## Structure

```
Core/
├── DI/                    # Dependency Injection
│   └── DIContainer.swift  # DI Container implementation
└── CoreModule.swift       # Module definition
```

## Dependency Injection Container

The DI Container manages all app dependencies with support for different scopes:

### Features
- **Singleton Scope**: Single instance throughout app lifetime
- **Transient Scope**: New instance for each resolution
- **Thread-Safe**: Safe for concurrent access
- **Type-Safe**: Compile-time type checking

### Usage

#### Registration
```swift
let container = DIContainer.shared

// Singleton registration
container.register(NetworkClientProtocol.self, scope: .singleton) { _ in
    NetworkClient(
        session: URLSession.shared,
        baseURL: URL(string: "https://api.example.com")!
    )
}

// Transient registration
container.register(LoginUseCaseProtocol.self, scope: .transient) { container in
    LoginUseCase(
        authService: container.require(AuthServiceProtocol.self),
        userRepository: container.require(UserRepositoryProtocol.self)
    )
}
```

#### Resolution
```swift
// Safe resolution (returns optional)
if let service = container.resolve(NetworkClientProtocol.self) {
    // Use service
}

// Required resolution (crashes if not found)
let service = container.require(NetworkClientProtocol.self)
```

### Scopes Explained

#### Singleton Scope
- Created once and reused
- Good for: Network clients, persistence, app-wide services
- Example: `NetworkClient`, `SwiftDataPersistence`

#### Transient Scope
- New instance each time
- Good for: Use cases, temporary objects
- Example: `LoginUseCase`, `RecordHealthMetricUseCase`

## App Dependencies Setup

The `AppDependencies` class configures all dependencies at app startup:

```swift
public final class AppDependencies {
    private let container: DIContainer
    
    public func configure() {
        configureInfrastructure()
        configureDataLayer()
        configureDomainLayer()
        configureUILayer()
    }
}
```

### Layer Configuration Order
1. **Infrastructure**: Network, persistence, external services
2. **Data Layer**: Repositories that depend on infrastructure
3. **Domain Layer**: Use cases that depend on repositories
4. **UI Layer**: ViewModels and factories

## Testing with DI

The DI container makes testing easy by allowing mock injection:

```swift
class DIContainerTests: XCTestCase {
    func test_mockInjection() {
        // Given
        let container = DIContainer()
        let mockService = MockNetworkClient()
        
        // When
        container.register(NetworkClientProtocol.self) { _ in
            mockService
        }
        
        // Then
        let resolved = container.resolve(NetworkClientProtocol.self)
        XCTAssertTrue(resolved === mockService)
    }
}
```

## Best Practices

1. **Register Early**: Configure all dependencies at app startup
2. **Protocol-Based**: Always register protocols, not concrete types
3. **Scope Appropriately**: Choose the right scope for each dependency
4. **Avoid Circular Dependencies**: Design to prevent circular references
5. **Test with Mocks**: Use DI to inject test doubles