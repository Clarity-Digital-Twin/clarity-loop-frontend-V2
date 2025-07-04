# CLARITY Swift 6 + SwiftData Sendability Guide

## 🚨 Critical: Swift 6 Concurrency + SwiftData = Compiler Errors

This guide documents the professional solutions for handling Swift 6 sendability issues with SwiftData in the CLARITY Pulse V2 application.

## The Core Problem

SwiftData's `ModelContext` and `@Model` objects are **NOT Sendable** in Swift 6, which causes compilation errors when:
- Passing ModelContext across actor boundaries
- Using SwiftData models in async/await contexts
- Implementing repository patterns with actors
- Working with background queues

## Professional Solutions (Ranked by Apple's Recommendations)

### 1. ModelActor Pattern (Apple's Recommended Approach)

```swift
// ✅ BEST PRACTICE - Use ModelActor for background operations
@ModelActor
actor DataRepository {
    // ModelActor provides a ModelContext that's safe for this actor
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultModelExecutor(modelContext: modelContext)
        self.modelContainer = modelContainer
    }
    
    func create<T: PersistentModel>(_ model: T) throws {
        modelContext.insert(model)
        try modelContext.save()
    }
}
```

### 2. Entity/Model Separation Pattern (CLARITY's Current Approach)

```swift
// ✅ DOMAIN ENTITY - Sendable
public struct HealthMetric: Sendable {
    public let id: UUID
    public let value: Double
    // All properties are Sendable
}

// ✅ SWIFTDATA MODEL - Not Sendable
@Model
final class PersistedHealthMetric {
    var id: UUID
    var value: Double
    // SwiftData managed properties
}

// ✅ MAPPER - Converts between worlds
public struct HealthMetricMapper: EntityMapper {
    func toModel(_ entity: HealthMetric) -> PersistedHealthMetric {
        PersistedHealthMetric(id: entity.id, value: entity.value)
    }
    
    func toEntity(_ model: PersistedHealthMetric) -> HealthMetric {
        HealthMetric(id: model.id, value: model.value)
    }
}
```

### 3. MainActor Context Pattern

```swift
// ✅ Use MainActor for UI-bound ModelContext operations
public actor SwiftDataRepository {
    private let modelContainer: ModelContainer
    
    @MainActor
    private func withContext<T>(_ work: (ModelContext) async throws -> T) async throws -> T {
        let context = modelContainer.mainContext
        return try await work(context)
    }
    
    public func create(_ entity: Entity) async throws -> Entity {
        try await withContext { context in
            let model = mapper.toModel(entity)
            context.insert(model)
            try context.save()
            return mapper.toEntity(model)
        }
    }
}
```

### 4. Sendable DTO Pattern (For Complex Queries)

```swift
// ✅ Create Sendable DTOs for complex data transfer
public struct HealthMetricDTO: Sendable {
    public let id: UUID
    public let value: Double
    public let metadata: [String: String]
}

@ModelActor
actor HealthMetricService {
    func fetchMetrics() async throws -> [HealthMetricDTO] {
        let models = try modelContext.fetch(FetchDescriptor<PersistedHealthMetric>())
        // Convert to Sendable DTOs
        return models.map { model in
            HealthMetricDTO(
                id: model.id,
                value: model.value,
                metadata: [:] // Convert non-Sendable data
            )
        }
    }
}
```

## Implementation Guidelines

### Repository Implementation Pattern

```swift
// ✅ CORRECT - Full implementation pattern
public actor SwiftDataRepository<
    EntityType: Entity & Sendable,
    ModelType: PersistentModel,
    MapperType: EntityMapper & Sendable
>: Repository where MapperType.Entity == EntityType, MapperType.Model == ModelType {
    
    private let modelContainer: ModelContainer
    private let mapper: MapperType
    
    public init(modelContainer: ModelContainer, mapper: MapperType) {
        self.modelContainer = modelContainer
        self.mapper = mapper
    }
    
    // Use MainActor for context operations
    @MainActor
    private func performOperation<T>(_ operation: (ModelContext) throws -> T) async throws -> T {
        let context = modelContainer.mainContext
        return try operation(context)
    }
    
    public func create(_ entity: EntityType) async throws -> EntityType {
        try await performOperation { context in
            let model = mapper.toModel(entity)
            context.insert(model)
            try context.save()
            return mapper.toEntity(model)
        }
    }
}
```

### Error Handling Pattern

```swift
// ✅ Handle concurrency-specific errors
enum RepositoryError: Error, Sendable {
    case contextUnavailable
    case mappingFailed
    case concurrencyViolation
}

public func fetch(id: UUID) async throws -> EntityType? {
    do {
        return try await performOperation { context in
            let descriptor = FetchDescriptor<ModelType>(
                predicate: #Predicate { $0.id == id }
            )
            guard let model = try context.fetch(descriptor).first else {
                return nil
            }
            return mapper.toEntity(model)
        }
    } catch {
        throw RepositoryError.contextUnavailable
    }
}
```

## Common Compiler Errors and Fixes

### Error 1: "ModelContext does not conform to Sendable"
```swift
// ❌ WRONG
actor MyRepository {
    private let context: ModelContext // Error: Non-Sendable stored property
}

// ✅ CORRECT
actor MyRepository {
    private let modelContainer: ModelContainer // Container is Sendable
    
    @MainActor
    private var context: ModelContext {
        modelContainer.mainContext
    }
}
```

### Error 2: "Sending non-Sendable result across actors"
```swift
// ❌ WRONG
func fetchModel() async -> PersistedModel // Error: Model is not Sendable

// ✅ CORRECT
func fetchEntity() async -> Entity // Entity is Sendable
```

### Error 3: "Non-Sendable parameter in async function"
```swift
// ❌ WRONG
func process(_ model: PersistedModel) async // Error

// ✅ CORRECT
func process(_ entity: Entity) async // Entity is Sendable
```

## Testing Patterns

```swift
// ✅ Test with mock repositories
final class MockRepository: Repository, @unchecked Sendable {
    private var storage: [UUID: Entity] = [:]
    private let lock = NSLock()
    
    func create(_ entity: Entity) async throws -> Entity {
        lock.withLock {
            storage[entity.id] = entity
        }
        return entity
    }
}
```

## Migration Checklist

When migrating existing SwiftData code to Swift 6:

- [ ] Separate domain entities (Sendable) from SwiftData models (non-Sendable)
- [ ] Create mappers for entity/model conversion
- [ ] Use ModelActor for background operations
- [ ] Use @MainActor for UI-bound operations
- [ ] Replace direct ModelContext passing with MainActor methods
- [ ] Create Sendable DTOs for complex data transfer
- [ ] Add proper error handling for concurrency issues
- [ ] Test with complete concurrency checking enabled

## Build Settings

Ensure your project has strict concurrency checking:

```swift
// Package.swift
.target(
    name: "ClarityData",
    swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
    ]
)
```

## Known Issues and Workarounds

### Issue 1: ModelContext in Previews
```swift
// SwiftUI previews need special handling
#Preview {
    ContentView()
        .modelContainer(for: PersistedModel.self, inMemory: true)
}
```

### Issue 2: Background Queue Operations
```swift
// Use ModelActor instead of dispatch queues
@ModelActor
actor BackgroundProcessor {
    // Operations run on ModelActor's executor
}
```

### Issue 3: SwiftData Batch Operations
```swift
// Batch operations need careful handling
@MainActor
func batchUpdate() async throws {
    let context = modelContainer.mainContext
    try context.transaction {
        // Batch operations within transaction
    }
}
```

## References

1. [Apple Developer Forums - SwiftData @Model Sendability](https://developer.apple.com/forums/thread/760709)
2. [ModelActor Documentation](https://developer.apple.com/documentation/swiftdata/modelactor)
3. [Swift 6 Migration Guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
4. [WWDC 2024 - SwiftData Best Practices](https://developer.apple.com/videos/play/wwdc2024/10138/)

## Summary

The professional approach for Swift 6 + SwiftData is:

1. **Use ModelActor** for dedicated background data operations
2. **Separate Entities from Models** for clean architecture
3. **Use @MainActor** for UI-bound operations
4. **Create Sendable DTOs** when needed
5. **Never pass ModelContext or @Model objects** across actor boundaries

This approach ensures type safety, prevents data races, and maintains clean architecture while working within Swift 6's strict concurrency requirements.