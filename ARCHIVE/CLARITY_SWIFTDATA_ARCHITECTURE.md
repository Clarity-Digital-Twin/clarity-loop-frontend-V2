# CLARITY SwiftData Architecture & Implementation Guide

## Overview
This document provides the complete SwiftData architecture for CLARITY Pulse, including models, relationships, migrations, and sync strategies.

## Core Principles

### 1. Local-First Architecture
- All data persisted locally using SwiftData
- Backend sync happens asynchronously
- UI always reads from local store
- Offline changes queued for sync

### 2. SwiftData Models

## Complete Data Model Architecture

### User Model
```swift
import SwiftData
import Foundation

@Model
final class User {
    // MARK: - Properties
    @Attribute(.unique) var id: String
    var email: String
    var firstName: String
    var lastName: String
    var isEmailVerified: Bool
    var createdAt: Date
    var lastSyncedAt: Date?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade) var healthMetrics: [HealthMetric]?
    @Relationship(deleteRule: .cascade) var insights: [Insight]?
    @Relationship(deleteRule: .cascade) var patAnalyses: [PATAnalysis]?
    @Relationship(deleteRule: .cascade) var syncQueue: [SyncQueueItem]?
    
    // MARK: - Initialization
    init(id: String, email: String, firstName: String, lastName: String) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.isEmailVerified = false
        self.createdAt = Date()
    }
}
```

### HealthMetric Model
```swift
@Model
final class HealthMetric {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var type: HealthMetricType
    var value: Double
    var unit: String
    var timestamp: Date
    var source: String
    var isSynced: Bool
    var syncedAt: Date?
    var localCreatedAt: Date
    
    // MARK: - Relationships
    var user: User?
    
    // MARK: - Metadata
    var metadata: [String: String]?
    
    init(type: HealthMetricType, value: Double, unit: String, timestamp: Date, source: String) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
        self.isSynced = false
        self.localCreatedAt = Date()
    }
}

enum HealthMetricType: String, Codable, CaseIterable {
    case steps = "steps"
    case heartRate = "heart_rate"
    case restingHeartRate = "resting_heart_rate"
    case heartRateVariability = "hrv"
    case bloodOxygen = "blood_oxygen"
    case bodyTemperature = "body_temperature"
    case respiratoryRate = "respiratory_rate"
    case sleepDuration = "sleep_duration"
    case deepSleep = "deep_sleep"
    case remSleep = "rem_sleep"
    case lightSleep = "light_sleep"
    case activeCalories = "active_calories"
    case distance = "distance"
}
```

### Insight Model
```swift
@Model
final class Insight {
    // MARK: - Properties
    @Attribute(.unique) var id: String
    var type: InsightType
    var summary: String
    var recommendations: [String]
    var metrics: Data // JSON encoded dictionary
    var generatedAt: Date
    var viewedAt: Date?
    var isRead: Bool
    
    // MARK: - Relationships
    var user: User?
    
    init(id: String, type: InsightType, summary: String, recommendations: [String], metrics: Data) {
        self.id = id
        self.type = type
        self.summary = summary
        self.recommendations = recommendations
        self.metrics = metrics
        self.generatedAt = Date()
        self.isRead = false
    }
}

enum InsightType: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case trend = "trend"
    case alert = "alert"
    case recommendation = "recommendation"
}
```

### PATAnalysis Model
```swift
@Model
final class PATAnalysis {
    // MARK: - Properties
    @Attribute(.unique) var analysisId: String
    var status: AnalysisStatus
    var dataSource: String
    var analysisType: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var completedAt: Date?
    
    // MARK: - Results
    var sleepQualityScore: Double?
    var circadianRhythmStability: Double?
    var sleepEfficiency: Double?
    var predictedSleepStages: Data? // JSON encoded array
    var anomalies: Data? // JSON encoded array
    
    // MARK: - Relationships
    var user: User?
    
    init(analysisId: String, dataSource: String, analysisType: String, startDate: Date, endDate: Date) {
        self.analysisId = analysisId
        self.status = .pending
        self.dataSource = dataSource
        self.analysisType = analysisType
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
    }
}

enum AnalysisStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}
```

### SyncQueueItem Model
```swift
@Model
final class SyncQueueItem {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var operation: SyncOperation
    var entityType: String
    var entityId: String
    var payload: Data
    var retryCount: Int
    var maxRetries: Int
    var createdAt: Date
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var error: String?
    
    // MARK: - Relationships
    var user: User?
    
    init(operation: SyncOperation, entityType: String, entityId: String, payload: Data) {
        self.id = UUID()
        self.operation = operation
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.retryCount = 0
        self.maxRetries = 3
        self.createdAt = Date()
    }
}

enum SyncOperation: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}
```

## ModelContainer Configuration

```swift
import SwiftData

final class DataController {
    static let shared = DataController()
    
    let container: ModelContainer
    
    private init() {
        do {
            let schema = Schema([
                User.self,
                HealthMetric.self,
                Insight.self,
                PATAnalysis.self,
                SyncQueueItem.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.com.clarity.pulse"),
                cloudKitDatabase: .none // We manage sync manually
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    @MainActor
    var viewContext: ModelContext {
        container.mainContext
    }
    
    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
```

## Migration Strategy

### Version 1 → Version 2 Migration
```swift
enum DataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        DataSchemaV1.self,
        DataSchemaV2.self
    ]
    
    static var stages: [MigrationStage] = [
        migrateV1toV2
    ]
}

// Version 1 Schema
enum DataSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [User.self, HealthMetric.self]
    }
}

// Version 2 Schema (adds new models)
enum DataSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [User.self, HealthMetric.self, Insight.self, PATAnalysis.self, SyncQueueItem.self]
    }
}

// Migration Stage
let migrateV1toV2 = MigrationStage.custom(
    fromVersion: DataSchemaV1.self,
    toVersion: DataSchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
        // Perform any data transformations needed
        let users = try context.fetch(FetchDescriptor<User>())
        for user in users {
            // Initialize new properties if needed
            user.lastSyncedAt = Date()
        }
        try context.save()
    }
)
```

## Sync Architecture

### Offline Queue Manager
```swift
import SwiftData

actor OfflineSyncManager {
    private let modelContext: ModelContext
    private let networkService: NetworkingProtocol
    
    init(modelContext: ModelContext, networkService: NetworkingProtocol) {
        self.modelContext = modelContext
        self.networkService = networkService
    }
    
    func queueOperation(_ operation: SyncOperation, for entity: any PersistentModel) async throws {
        let entityType = String(describing: type(of: entity))
        let entityId = entity.persistentModelID.hashValue.description
        let payload = try JSONEncoder().encode(entity)
        
        let queueItem = SyncQueueItem(
            operation: operation,
            entityType: entityType,
            entityId: entityId,
            payload: payload
        )
        
        modelContext.insert(queueItem)
        try modelContext.save()
    }
    
    func processSyncQueue() async {
        do {
            let descriptor = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate { item in
                    item.retryCount < item.maxRetries
                },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            
            let items = try modelContext.fetch(descriptor)
            
            for item in items {
                await processQueueItem(item)
            }
        } catch {
            print("Failed to fetch sync queue: \(error)")
        }
    }
    
    private func processQueueItem(_ item: SyncQueueItem) async {
        do {
            // Process based on operation type
            switch item.operation {
            case .create:
                try await syncCreate(item)
            case .update:
                try await syncUpdate(item)
            case .delete:
                try await syncDelete(item)
            }
            
            // Remove from queue on success
            modelContext.delete(item)
            try modelContext.save()
            
        } catch {
            // Update retry information
            item.retryCount += 1
            item.lastAttemptAt = Date()
            item.nextRetryAt = calculateNextRetryDate(retryCount: item.retryCount)
            item.error = error.localizedDescription
            
            try? modelContext.save()
        }
    }
    
    private func calculateNextRetryDate(retryCount: Int) -> Date {
        // Exponential backoff: 1min, 2min, 4min, 8min...
        let delay = pow(2.0, Double(retryCount)) * 60
        return Date().addingTimeInterval(delay)
    }
}
```

## Query Patterns

### Efficient Fetching
```swift
// Fetch recent health metrics with pagination
func fetchRecentHealthMetrics(limit: Int = 50, offset: Int = 0) throws -> [HealthMetric] {
    let descriptor = FetchDescriptor<HealthMetric>(
        predicate: #Predicate { metric in
            metric.user?.id == currentUserId
        },
        sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset
    
    return try modelContext.fetch(descriptor)
}

// Fetch unsynced items
func fetchUnsyncedHealthMetrics() throws -> [HealthMetric] {
    let descriptor = FetchDescriptor<HealthMetric>(
        predicate: #Predicate { metric in
            metric.isSynced == false
        }
    )
    return try modelContext.fetch(descriptor)
}

// Aggregate queries
func calculateDailySteps(for date: Date) throws -> Double {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let descriptor = FetchDescriptor<HealthMetric>(
        predicate: #Predicate { metric in
            metric.type == .steps &&
            metric.timestamp >= startOfDay &&
            metric.timestamp < endOfDay
        }
    )
    
    let metrics = try modelContext.fetch(descriptor)
    return metrics.reduce(0) { $0 + $1.value }
}
```

## Background Processing

```swift
import BackgroundTasks

final class BackgroundSyncManager {
    static let syncTaskIdentifier = "com.clarity.pulse.sync"
    
    func scheduleSyncTask() {
        let request = BGProcessingTaskRequest(identifier: Self.syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule sync task: \(error)")
        }
    }
    
    func handleSyncTask(_ task: BGProcessingTask) {
        let syncManager = OfflineSyncManager(
            modelContext: DataController.shared.newBackgroundContext(),
            networkService: DependencyContainer.shared.networking
        )
        
        Task {
            await syncManager.processSyncQueue()
            task.setTaskCompleted(success: true)
        }
        
        // Schedule next sync
        scheduleSyncTask()
    }
}
```

## Conflict Resolution

```swift
protocol ConflictResolver {
    func resolve<T: PersistentModel>(local: T, remote: T) -> T
}

struct HealthMetricConflictResolver: ConflictResolver {
    func resolve<T: PersistentModel>(local: T, remote: T) -> T {
        guard let localMetric = local as? HealthMetric,
              let remoteMetric = remote as? HealthMetric else {
            return local // Default to local if types don't match
        }
        
        // Resolution strategy: Latest timestamp wins
        if localMetric.timestamp > remoteMetric.timestamp {
            return local
        } else {
            return remote
        }
    }
}
```

## Testing SwiftData

### In-Memory Test Container
```swift
@MainActor
class SwiftDataTestCase: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let schema = Schema([
            User.self,
            HealthMetric.self,
            Insight.self,
            PATAnalysis.self,
            SyncQueueItem.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        
        context = container.mainContext
    }
    
    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }
}
```

### Example Test
```swift
final class HealthMetricPersistenceTests: SwiftDataTestCase {
    func testSaveAndFetchHealthMetric() async throws {
        // Arrange
        let user = User(id: "test", email: "test@example.com", firstName: "Test", lastName: "User")
        context.insert(user)
        
        let metric = HealthMetric(
            type: .heartRate,
            value: 72,
            unit: "bpm",
            timestamp: Date(),
            source: "Apple Watch"
        )
        metric.user = user
        context.insert(metric)
        
        // Act
        try context.save()
        
        let descriptor = FetchDescriptor<HealthMetric>()
        let fetchedMetrics = try context.fetch(descriptor)
        
        // Assert
        XCTAssertEqual(fetchedMetrics.count, 1)
        XCTAssertEqual(fetchedMetrics.first?.value, 72)
        XCTAssertEqual(fetchedMetrics.first?.user?.id, "test")
    }
}
```

## Performance Optimizations

### 1. Batch Operations
```swift
func batchInsertHealthMetrics(_ metrics: [HealthMetricDTO]) async throws {
    let context = DataController.shared.newBackgroundContext()
    
    context.autosaveEnabled = false
    
    for dto in metrics {
        let metric = HealthMetric(
            type: HealthMetricType(rawValue: dto.type) ?? .heartRate,
            value: dto.value,
            unit: dto.unit,
            timestamp: dto.timestamp,
            source: dto.source
        )
        context.insert(metric)
    }
    
    try context.save()
}
```

### 2. Lazy Loading
```swift
@Query(sort: \HealthMetric.timestamp, order: .reverse) 
private var recentMetrics: [HealthMetric]

// Use with fetchLimit for pagination
init(limit: Int) {
    _recentMetrics = Query(
        filter: #Predicate<HealthMetric> { _ in true },
        sort: \HealthMetric.timestamp,
        order: .reverse,
        fetchLimit: limit
    )
}
```

### 3. Index Optimization
Mark frequently queried properties for indexing:
```swift
@Model
final class HealthMetric {
    @Attribute(.unique, .indexed) var id: UUID
    @Attribute(.indexed) var timestamp: Date
    @Attribute(.indexed) var type: HealthMetricType
    // ... rest of properties
}
```

## Error Handling

```swift
enum SwiftDataError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case migrationFailed(Error)
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflict"
        }
    }
}
```

## Memory Management

```swift
// Clean up old data periodically
func cleanupOldData(olderThan days: Int = 90) async throws {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    
    let context = DataController.shared.newBackgroundContext()
    
    let descriptor = FetchDescriptor<HealthMetric>(
        predicate: #Predicate { metric in
            metric.timestamp < cutoffDate && metric.isSynced == true
        }
    )
    
    let oldMetrics = try context.fetch(descriptor)
    
    for metric in oldMetrics {
        context.delete(metric)
    }
    
    try context.save()
}
```

---

This architecture provides a robust foundation for offline-first data management with SwiftData, ensuring data integrity, performance, and seamless sync capabilities.