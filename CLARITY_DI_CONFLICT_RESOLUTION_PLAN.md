# CLARITY Dependency Injection Conflict Resolution Plan

## Executive Summary

The CLARITY app currently has **two conflicting dependency injection systems** that are causing critical runtime failures including black screens on device. This plan outlines how to resolve this architectural conflict and establish a single, coherent DI approach.

## Current State Analysis

### Problem: Two Competing DI Systems

1. **DIContainer (Legacy System)**
   - Location: `clarity-loop-frontend-v2/Core/DI/DIContainer.swift`
   - Usage: Views directly call `DIContainer.shared.require(...)`
   - Pattern: Service Locator anti-pattern
   - Issues: 
     - Global singleton state
     - No compile-time safety
     - Hard to test
     - Not SwiftUI-native

2. **Dependencies + Environment (Modern System)**
   - Location: `clarity-loop-frontend-v2/Core/DI/Dependencies.swift`
   - Usage: Via `.configuredDependencies()` and SwiftUI environment
   - Pattern: Proper dependency injection via environment
   - Benefits:
     - SwiftUI-native
     - Compile-time safe
     - Testable
     - No global state

### Root Cause of Black Screen

1. `LoginView` tries to resolve dependencies from `DIContainer.shared`
2. `AppDependencyConfigurator` configures a different container (`Dependencies`)
3. `DIContainer.shared` remains empty, causing crashes when views try to access it
4. The app shows a black screen due to the crash

## Proposed Solution

### Phase 1: Immediate Fix (1-2 hours)
**Goal**: Get the app running on device TODAY

1. **Option A: Bridge Pattern** (Recommended for immediate fix)
   - Make `AppDependencyConfigurator` populate BOTH containers
   - This allows existing views to work while we refactor
   - Low risk, high reward

2. **Option B: Quick Migration**
   - Update all views to use Environment-based DI
   - Higher risk but cleaner

### Phase 2: Architectural Cleanup (4-6 hours)
**Goal**: Remove the legacy DIContainer completely

1. **Migrate all views to Environment-based DI**
   - Replace `DIContainer.shared.require()` calls
   - Use `@Environment` for dependency access
   - Create proper environment keys

2. **Update ViewModels and Factories**
   - Remove dependency on DIContainer
   - Use constructor injection
   - Make factories environment-aware

3. **Delete Legacy Code**
   - Remove DIContainer.swift
   - Remove all service locator patterns
   - Clean up unused dependencies

### Phase 3: Best Practices Implementation (2-3 hours)
**Goal**: Establish patterns for future development

1. **Create DI Guidelines**
   - Document the approved DI approach
   - Create code examples
   - Add to CLAUDE.md

2. **Add Compile-Time Checks**
   - Use protocols to enforce DI patterns
   - Add SwiftLint rules
   - Create unit tests for DI

## Implementation Plan

### Step 1: Bridge Pattern Implementation

```swift
// In AppDependencyConfigurator
public func configure(_ dependencies: Dependencies) {
    // Configure modern container
    configureInfrastructure(dependencies)
    configureDataLayer(dependencies)
    configureDomainLayer(dependencies)
    configureUILayer(dependencies)
    
    // BRIDGE: Also configure legacy container
    configureLegacyContainer(dependencies)
}

private func configureLegacyContainer(_ dependencies: Dependencies) {
    let container = DIContainer.shared
    
    // Mirror all registrations to legacy container
    container.register(LoginViewModelFactory.self) { _ in
        DefaultLoginViewModelFactory(
            loginUseCase: dependencies.require(LoginUseCaseProtocol.self)
        )
    }
    
    container.register(DashboardViewModelFactory.self) { _ in
        DefaultDashboardViewModelFactory(
            healthMetricRepository: dependencies.require(HealthMetricRepositoryProtocol.self)
        )
    }
    
    // Add all other required registrations...
}
```

### Step 2: View Migration Pattern

```swift
// BEFORE (using DIContainer)
public struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    public init() {
        let container = DIContainer.shared
        let factory = container.require(LoginViewModelFactory.self)
        let loginUseCase = factory.create()
        self._viewModel = State(wrappedValue: LoginViewModel(loginUseCase: loginUseCase))
    }
}

// AFTER (using Environment)
public struct LoginView: View {
    @Environment(\.loginViewModelFactory) private var factory
    @State private var viewModel: LoginViewModel
    
    public init() {
        // Dependencies injected via environment
    }
    
    public var body: some View {
        // Use onAppear to initialize with injected dependencies
        VStack { ... }
        .onAppear {
            if viewModel == nil {
                viewModel = factory.create()
            }
        }
    }
}
```

### Step 3: Environment Key Pattern

```swift
// Define environment keys
struct LoginViewModelFactoryKey: EnvironmentKey {
    static let defaultValue: LoginViewModelFactory? = nil
}

extension EnvironmentValues {
    var loginViewModelFactory: LoginViewModelFactory? {
        get { self[LoginViewModelFactoryKey.self] }
        set { self[LoginViewModelFactoryKey.self] = newValue }
    }
}

// Extension to inject factory
extension View {
    func loginViewModelFactory(_ factory: LoginViewModelFactory) -> some View {
        environment(\.loginViewModelFactory, factory)
    }
}
```

## Risk Assessment

### Risks
1. **Breaking existing functionality** - Mitigated by bridge pattern
2. **Missing dependencies** - Mitigated by comprehensive testing
3. **Performance impact** - Minimal, Environment is efficient

### Benefits
1. **Eliminates black screen issue**
2. **Improves testability**
3. **Aligns with SwiftUI best practices**
4. **Removes global state**
5. **Enables proper dependency mocking**

## Success Criteria

1. ✅ App launches without black screen on device
2. ✅ All views receive required dependencies
3. ✅ No calls to DIContainer.shared remain
4. ✅ All tests pass
5. ✅ New DI approach documented

## Timeline

- **Day 1 (Today)**: Implement bridge pattern, get app running
- **Day 2**: Migrate 50% of views to new pattern
- **Day 3**: Complete migration, remove legacy code
- **Day 4**: Documentation and testing

## Next Steps

1. Implement bridge pattern immediately
2. Test on device
3. Begin systematic migration
4. Update documentation
5. Remove legacy code

---

**Priority**: CRITICAL
**Impact**: Blocks all development and testing
**Effort**: Medium (8-12 hours total)
**Risk**: Low with bridge pattern approach