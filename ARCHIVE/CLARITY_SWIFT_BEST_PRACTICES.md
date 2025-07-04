# CLARITY Swift Best Practices & Common AI Agent Pitfalls

## Critical: This is an APPLICATION, Not a Framework!

### Access Control Rules for Applications

**DEFAULT TO PRIVATE** - This is the #1 rule that AI agents violate!

```swift
// ❌ WRONG - AI agents often do this (framework mindset)
public class HealthViewModel: ObservableObject {
    public var healthData: [HealthMetric] = []
    public func loadData() { }
}

// ✅ CORRECT - Application code should be private by default
@Observable
final class HealthViewModel {
    private(set) var healthData: [HealthMetric] = []
    
    func loadData() { } // internal by default
}
```

### Access Control Hierarchy for iOS Apps

1. **private** - Use for ALL implementation details
2. **fileprivate** - Use when needed within same file
3. **internal** (default) - Use for module-internal access
4. **public/open** - NEVER use in application code!

## Common AI Agent Mistakes to Avoid

### 1. Public Everything Syndrome
```swift
// ❌ AI AGENTS LOVE TO DO THIS - DON'T!
public protocol NetworkingProtocol {
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

public final class NetworkManager: NetworkingProtocol {
    public static let shared = NetworkManager()
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T { }
}

// ✅ CORRECT - Keep it internal to the app
protocol NetworkingProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

final class NetworkManager: NetworkingProtocol {
    static let shared = NetworkManager()
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T { }
}
```

### 2. Exposing Internal Types
```swift
// ❌ WRONG - Exposing implementation details
public struct APIResponse<T: Decodable>: Decodable {
    public let data: T
    public let meta: ResponseMetadata
}

// ✅ CORRECT - Keep types internal
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let meta: ResponseMetadata
}
```

### 3. Unnecessary Protocol Conformance Exposure
```swift
// ❌ WRONG - Making conformances public
public final class UserRepository: public RepositoryProtocol {
    public func fetch() async throws -> [User] { }
}

// ✅ CORRECT - Internal conformance
final class UserRepository: RepositoryProtocol {
    func fetch() async throws -> [User] { }
}
```

## Swift Best Practices for Production Apps

### 1. Property Access Control
```swift
@Observable
final class DashboardViewModel {
    // ✅ CORRECT - Expose read access, keep write access private
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    // ✅ CORRECT - Truly private implementation details
    private let repository: HealthDataRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // ✅ CORRECT - Computed properties for derived state
    var hasError: Bool {
        errorMessage != nil
    }
}
```

### 2. Method Visibility
```swift
final class HealthKitService {
    // ✅ Public API (internal to app)
    func requestAuthorization() async throws { 
        try await performAuthorization()
    }
    
    // ✅ Private implementation
    private func performAuthorization() async throws {
        // Implementation details
    }
    
    // ✅ Private helper methods
    private func mapHealthKitError(_ error: Error) -> HealthError {
        // Error mapping
    }
}
```

### 3. Extension Visibility
```swift
// ❌ WRONG - Public extension in app code
public extension Date {
    public func toHealthFormat() -> String { }
}

// ✅ CORRECT - Internal extension
extension Date {
    func toHealthFormat() -> String { }
}

// ✅ EVEN BETTER - Scoped to where needed
private extension Date {
    func toHealthFormat() -> String { }
}
```

### 4. Protocol Design for Apps
```swift
// ✅ CORRECT - Internal protocol with focused responsibility
protocol HealthDataSyncable {
    associatedtype DataType: Codable
    
    func sync(_ data: DataType) async throws
    func fetchPendingSync() async throws -> [DataType]
}

// ❌ WRONG - Over-engineered public protocol
public protocol DataSynchronizationProtocol {
    associatedtype Request: Encodable
    associatedtype Response: Decodable
    
    public func synchronize<T>(_ request: Request) async throws -> Response
}
```

### 5. Error Handling
```swift
// ✅ CORRECT - App-specific errors, not public
enum HealthDataError: LocalizedError {
    case authorizationDenied
    case dataNotAvailable
    case syncFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Health data access was denied"
        case .dataNotAvailable:
            return "No health data available"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}
```

### 6. Singleton Pattern for Apps
```swift
// ❌ WRONG - Public singleton
public class DataManager {
    public static let shared = DataManager()
    public init() { } // Even worse!
}

// ✅ CORRECT - Controlled singleton
final class DataManager {
    static let shared = DataManager()
    
    private init() { 
        // Private initialization
    }
}
```

### 7. SwiftUI View Modifiers
```swift
// ❌ WRONG - Public view modifier in app
public extension View {
    public func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

// ✅ CORRECT - Internal view modifier
extension View {
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 4)
    }
}
```

### 8. Type Aliases and Nested Types
```swift
// ✅ CORRECT - Keep type aliases internal
typealias CompletionHandler<T> = (Result<T, Error>) -> Void

final class APIClient {
    // ✅ Nested types are implicitly internal
    enum Endpoint {
        case login(email: String, password: String)
        case healthData(userId: String)
    }
    
    // ✅ Private nested types for implementation
    private struct RequestConfiguration {
        let timeout: TimeInterval
        let retryCount: Int
    }
}
```

### 9. Generic Constraints
```swift
// ❌ WRONG - Overly public generic
public class Repository<T: Codable> {
    public func save(_ item: T) { }
}

// ✅ CORRECT - Internal generic with constraints
final class Repository<Model: PersistentModel> {
    private let modelContext: ModelContext
    
    func save(_ model: Model) throws {
        modelContext.insert(model)
        try modelContext.save()
    }
}
```

### 10. Property Wrappers
```swift
// ❌ WRONG - Public property wrapper in app
@propertyWrapper
public struct Validated<Value> {
    public var wrappedValue: Value
}

// ✅ CORRECT - Internal property wrapper
@propertyWrapper
struct Validated<Value> {
    private var value: Value
    private let validator: (Value) -> Bool
    
    var wrappedValue: Value {
        get { value }
        set {
            if validator(newValue) {
                value = newValue
            }
        }
    }
}
```

## Testing Considerations

### Test Target Access
```swift
// In your app code
@testable import ClarityPulse // Allows testing internal code

// ✅ CORRECT - Test helpers are internal
final class MockHealthRepository: HealthRepositoryProtocol {
    var shouldFail = false
    
    func fetchHealthData() async throws -> [HealthData] {
        if shouldFail {
            throw TestError.mockFailure
        }
        return []
    }
}
```

## SwiftData & Core Data Specifics

### Model Access Control
```swift
// ✅ CORRECT - Models are internal
@Model
final class HealthMetric {
    var id: UUID
    var type: String
    var value: Double
    
    // Even init is internal
    init(type: String, value: Double) {
        self.id = UUID()
        self.type = type
        self.value = value
    }
}
```

## Preventing AI Agent Confusion

### 1. File Headers
Always start files with a comment clarifying this is application code:

```swift
//
//  HealthViewModel.swift
//  ClarityPulse
//
//  This is APPLICATION code - all types should be internal or private
//  DO NOT make anything public unless absolutely necessary
//
```

### 2. Access Control Assertions
Add build-time checks:

```swift
#if DEBUG
// Ensure we're not accidentally exposing public APIs
func validateAccessControl() {
    // This will fail to compile if types are public
    let _: HealthViewModel = HealthViewModel()
    let _: NetworkManager = NetworkManager.shared
}
#endif
```

### 3. Linting Rules
Configure SwiftLint to catch public declarations:

```yaml
# .swiftlint.yml
explicit_acl:
  severity: error
  
public_type_in_app:
  severity: error
  message: "Application code should not contain public types"
```

## Memory Management Best Practices

### 1. Weak References in Closures
```swift
final class DataSyncManager {
    private var timer: Timer?
    
    func startSync() {
        // ✅ CORRECT - Weak self in closures
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.performSync()
            }
        }
    }
}
```

### 2. Unowned vs Weak
```swift
// ✅ Use weak when reference might become nil
class ViewController {
    var viewModel: ViewModel?
    
    func setup() {
        viewModel?.onUpdate = { [weak self] in
            self?.updateUI()
        }
    }
}

// ✅ Use unowned for guaranteed non-nil references
class ChildViewModel {
    unowned let parent: ParentViewModel
    
    init(parent: ParentViewModel) {
        self.parent = parent
    }
}
```

## Concurrency Best Practices

### 1. Actor Isolation
```swift
// ✅ CORRECT - Use actors for thread-safe state
actor CacheManager {
    private var cache: [String: Data] = [:]
    
    func store(_ data: Data, for key: String) {
        cache[key] = data
    }
    
    func retrieve(for key: String) -> Data? {
        cache[key]
    }
}
```

### 2. MainActor Usage
```swift
@Observable
final class ViewModel {
    var uiState: UIState = .idle
    
    func updateData() async {
        // ✅ CORRECT - UI updates on MainActor
        await MainActor.run {
            uiState = .loading
        }
        
        do {
            let data = try await fetchData()
            await MainActor.run {
                uiState = .success(data)
            }
        } catch {
            await MainActor.run {
                uiState = .error(error)
            }
        }
    }
}
```

## Common Patterns to Enforce

### 1. Repository Pattern
```swift
// ✅ CORRECT - Protocol for testing, implementation is final
protocol HealthRepositoryProtocol {
    func fetch() async throws -> [HealthData]
}

final class HealthRepository: HealthRepositoryProtocol {
    private let networkClient: NetworkingProtocol
    
    init(networkClient: NetworkingProtocol) {
        self.networkClient = networkClient
    }
    
    func fetch() async throws -> [HealthData] {
        // Implementation
    }
}
```

### 2. Dependency Injection
```swift
// ✅ CORRECT - Dependencies injected, not hard-coded
final class HealthViewModel {
    private let repository: HealthRepositoryProtocol
    private let logger: LoggerProtocol
    
    init(
        repository: HealthRepositoryProtocol = DependencyContainer.shared.healthRepository,
        logger: LoggerProtocol = DependencyContainer.shared.logger
    ) {
        self.repository = repository
        self.logger = logger
    }
}
```

## Checklist for Every File

Before committing any Swift file, verify:

- [ ] No `public` or `open` declarations (unless absolutely required)
- [ ] All properties use appropriate access control
- [ ] Private methods are marked `private`
- [ ] No unnecessary protocol conformances exposed
- [ ] Singletons have private initializers
- [ ] Extensions are properly scoped
- [ ] Test helpers use `@testable import`
- [ ] Weak/unowned used appropriately in closures
- [ ] Types are `final` unless inheritance needed

## AI Agent Instructions Template

When working with AI agents, always include this prompt:

```
This is an iOS APPLICATION, not a framework or library. 
Follow these rules:
1. NEVER use 'public' or 'open' access modifiers
2. Default everything to 'private' 
3. Use 'internal' only when needed within the module
4. Mark all classes as 'final' unless inheritance is required
5. Use private(set) for read-only properties
6. This is a production app with no public API
```

---

Remember: Every `public` declaration in application code is a code smell. When in doubt, make it private!