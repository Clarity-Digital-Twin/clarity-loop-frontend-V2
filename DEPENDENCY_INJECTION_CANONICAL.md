# 🏗️ CLARITY Pulse - Canonical Dependency Injection Architecture

> **CRITICAL**: This is the SINGLE SOURCE OF TRUTH for all dependency injection in CLARITY Pulse.
> Any deviation from this document is a bug that must be fixed immediately.

## 🚨 Current Issues (As of 2025-07-02)

1. **FatalErrorLoginUseCase** is being used instead of real implementation
2. Dependencies not properly passed through view hierarchy
3. Duplicate AuthService implementations
4. Missing withDependencies() call in RootView

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ClarityPulseWrapperApp                    │
│  - Creates Dependencies container ONCE                       │
│  - Configures with AppDependencyConfigurator                │
│  - Passes to RootView                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         RootView                             │
│  - Receives dependencies via init                            │
│  - Configures Amplify ONCE (not in App)                    │
│  - Passes dependencies to ALL child views                   │
│  - MUST call .withDependencies(dependencies) on children    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Child Views (LoginView, etc)            │
│  - Receive dependencies via @Environment                    │
│  - Use factories to create ViewModels                       │
│  - NEVER create their own dependencies                      │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Dependency Container Structure

### Core Container: `Dependencies`
```swift
// Location: /Core/DI/Dependencies.swift
public final class Dependencies: ObservableObject {
    private var services: [ObjectIdentifier: Any] = [:]
    
    public func register<T>(_ type: T.Type, _ factory: () -> T)
    public func require<T>(_ type: T.Type) -> T
}
```

### Configuration: `AppDependencyConfigurator`
```swift
// Location: /UI/Common/AppDependencies+SwiftUI.swift
public final class AppDependencyConfigurator {
    public func configure(_ container: Dependencies) {
        // Order matters! Dependencies must be registered before use
        configureInfrastructure(container)
        configureDataLayer(container)
        configureDomainLayer(container)
        configureUILayer(container)
    }
}
```

## 📦 Service Registration Order

### 1. Infrastructure Layer
```swift
// No dependencies on other layers
container.register(KeychainServiceProtocol.self) { KeychainService() }
container.register(TokenStorageProtocol.self) { 
    TokenStorage(keychain: container.require(KeychainServiceProtocol.self))
}
container.register(BiometricAuthServiceProtocol.self) { BiometricAuthService() }
container.register(AuthServiceProtocol.self) { AmplifyAuthService() }  // ← SINGLE implementation
container.register(NetworkServiceProtocol.self) { ... }
container.register(APIClientProtocol.self) { ... }
container.register(ModelContainer.self) { ... }
container.register(PersistenceServiceProtocol.self) { ... }
container.register(AmplifyConfigurable.self) { AmplifyConfiguration() }
```

### 2. Data Layer
```swift
// Depends on Infrastructure
container.register(UserRepositoryProtocol.self) { 
    UserRepositoryImplementation(
        apiClient: container.require(APIClientProtocol.self),
        persistence: container.require(PersistenceServiceProtocol.self)
    )
}
container.register(HealthMetricRepositoryProtocol.self) { ... }
```

### 3. Domain Layer
```swift
// Depends on Data layer
container.register(LoginUseCaseProtocol.self) {
    LoginUseCase(  // ← REAL implementation, NOT FatalError
        authService: container.require(AuthServiceProtocol.self),
        userRepository: container.require(UserRepositoryProtocol.self)
    )
}
container.register(RecordHealthMetricUseCase.self) { ... }
```

### 4. UI Layer
```swift
// Depends on Domain layer
container.register(LoginViewModelFactory.self) {
    DefaultLoginViewModelFactory(
        loginUseCase: container.require(LoginUseCaseProtocol.self)  // ← Uses REAL use case
    )
}
container.register(DashboardViewModelFactory.self) { ... }
```

## 🎯 View Dependency Injection

### App Entry Point
```swift
@main
struct ClarityPulseWrapperApp: App {
    private let dependencies: Dependencies
    
    init() {
        let deps = Dependencies()
        let configurator = AppDependencyConfigurator()
        configurator.configure(deps)
        self.dependencies = deps
        // DO NOT configure Amplify here
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies, appState: appState)
                .environment(appState)
                .environmentObject(dependencies)
        }
    }
}
```

### Root View
```swift
struct RootView: View {
    let dependencies: Dependencies
    
    var body: some View {
        Group {
            if showLoginView {
                LoginView()
                    .withDependencies(dependencies)  // ← CRITICAL: Must call this!
            }
        }
        .task {
            // Configure Amplify ONCE here
            let amplifyConfig = dependencies.require(AmplifyConfigurable.self)
            try await amplifyConfig.configure()
        }
    }
}
```

### Child Views
```swift
public struct LoginView: View {
    @Environment(\.loginViewModelFactory) private var factory  // ← Gets REAL factory
    
    var body: some View {
        // factory.create() returns REAL LoginUseCase, not FatalError
    }
}
```

## ⚠️ Common Mistakes to Avoid

1. **NEVER** have duplicate service implementations
2. **NEVER** configure Amplify more than once
3. **NEVER** use FatalError implementations in production
4. **ALWAYS** call .withDependencies() when navigating to new views
5. **ALWAYS** use the same Dependencies instance throughout the app
6. **NEVER** create services directly in views - always use DI

## 🔍 How to Verify DI is Working

1. **No Fatal Errors**: App should not crash with "💥 LoginUseCaseProtocol not injected"
2. **Single Instances**: Services should be singletons (same instance everywhere)
3. **Proper Flow**: Login should actually call backend, not crash
4. **No Duplicates**: Search for duplicate class names should return only one result

## 📊 Service Dependency Graph

```
KeychainService (no deps)
    └── TokenStorage
            └── NetworkService
                    └── APIClient

BiometricAuthService (no deps)

AmplifyAuthService (no deps)
    └── LoginUseCase
            └── LoginViewModelFactory
                    └── LoginView

ModelContainerFactory (no deps)
    └── ModelContainer
            └── SwiftDataPersistence
                    └── UserRepository & HealthMetricRepository
                            └── Use Cases
                                    └── ViewModelFactories
                                            └── Views
```

## 🚀 Migration Checklist

- [x] Remove duplicate AmplifyAuthService from AppDependencies+SwiftUI.swift
- [x] Fix RootView to call .withDependencies() on LoginView
- [ ] Remove all FatalError implementations from production code
- [ ] Ensure AmplifyConfiguration is only called once in RootView
- [ ] Add unit tests to verify DI container works correctly
- [ ] Add integration test to verify login flow works end-to-end

## 🧪 Testing Strategy

1. **Unit Tests**: Mock all protocols at their registration point
2. **Integration Tests**: Use real implementations but mock network
3. **UI Tests**: Use completely real stack with test backend

---

**Last Updated**: 2025-07-02
**Status**: FIXING CRITICAL ISSUES
**Next Review**: After login flow works end-to-end