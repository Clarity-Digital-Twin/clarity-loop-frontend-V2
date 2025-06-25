# CLARITY Offline Sync Architecture

## Overview
This document provides the complete offline-first sync architecture for CLARITY Pulse, ensuring seamless operation without network connectivity and reliable data synchronization when reconnected.

## Core Principles

1. **Offline-First**: App must be fully functional without network
2. **Conflict Resolution**: Automatic resolution with user intervention only when necessary
3. **Data Integrity**: No data loss during sync operations
4. **Queue Reliability**: Persist sync queue across app restarts
5. **Optimistic Updates**: Immediate UI updates with background sync

## Sync Queue Architecture

### Queue Data Model

```swift
import SwiftData

// Sync queue item
@Model
final class SyncQueueItem {
    let id: UUID
    let operationType: SyncOperationType
    let entityType: String
    let entityId: String
    let payload: Data
    let createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var status: SyncStatus
    var errorMessage: String?
    
    init(
        operationType: SyncOperationType,
        entityType: String,
        entityId: String,
        payload: Data
    ) {
        self.id = UUID()
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
        self.status = .pending
    }
}

enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
    case batchUpdate
}

enum SyncStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}
```

### Sync Queue Manager

```swift
@Observable
final class SyncQueueManager {
    private let modelContext: ModelContext
    private let networkService: NetworkServiceProtocol
    private let conflictResolver: ConflictResolver
    
    // Queue processing state
    private(set) var isProcessing = false
    private(set) var pendingCount = 0
    private let maxConcurrentOperations = 3
    private let maxRetryAttempts = 3
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isOnline = false
    
    init(
        modelContext: ModelContext,
        networkService: NetworkServiceProtocol,
        conflictResolver: ConflictResolver
    ) {
        self.modelContext = modelContext
        self.networkService = networkService
        self.conflictResolver = conflictResolver
        
        setupNetworkMonitoring()
    }
}
```

### Queue Operations

```swift
extension SyncQueueManager {
    // Add operation to queue
    func enqueue<T: Codable>(
        operation: SyncOperationType,
        entity: T,
        entityType: String,
        entityId: String
    ) throws {
        let payload = try JSONEncoder().encode(entity)
        
        let queueItem = SyncQueueItem(
            operationType: operation,
            entityType: entityType,
            entityId: entityId,
            payload: payload
        )
        
        modelContext.insert(queueItem)
        try modelContext.save()
        
        pendingCount += 1
        
        // Try to process immediately if online
        if isOnline && !isProcessing {
            Task {
                await processQueue()
            }
        }
    }
    
    // Process queue
    func processQueue() async {
        guard isOnline && !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let pendingItems = try await fetchPendingItems()
            
            // Process in batches
            for batch in pendingItems.chunked(into: maxConcurrentOperations) {
                await processBatch(batch)
            }
        } catch {
            // Log error but don't crash
            print("Queue processing error: \(error)")
        }
    }
    
    private func processBatch(_ items: [SyncQueueItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { [weak self] in
                    await self?.processItem(item)
                }
            }
        }
    }
}
```

### Individual Item Processing

```swift
extension SyncQueueManager {
    private func processItem(_ item: SyncQueueItem) async {
        // Update status
        item.status = .inProgress
        item.lastAttemptAt = Date()
        try? modelContext.save()
        
        do {
            switch item.operationType {
            case .create:
                try await processCreate(item)
            case .update:
                try await processUpdate(item)
            case .delete:
                try await processDelete(item)
            case .batchUpdate:
                try await processBatchUpdate(item)
            }
            
            // Mark as completed
            item.status = .completed
            pendingCount = max(0, pendingCount - 1)
            
        } catch {
            await handleSyncError(item, error: error)
        }
        
        try? modelContext.save()
    }
    
    private func processCreate(_ item: SyncQueueItem) async throws {
        let endpoint = EndpointBuilder.create(entityType: item.entityType)
        let response = try await networkService.request(
            endpoint: endpoint,
            body: item.payload
        )
        
        // Update local entity with server ID
        try await updateLocalEntity(
            item: item,
            serverResponse: response
        )
    }
    
    private func processUpdate(_ item: SyncQueueItem) async throws {
        let endpoint = EndpointBuilder.update(
            entityType: item.entityType,
            id: item.entityId
        )
        
        do {
            let response = try await networkService.request(
                endpoint: endpoint,
                body: item.payload
            )
            
            // Update succeeded
            try await mergeServerResponse(item: item, response: response)
            
        } catch NetworkError.conflict(let serverData) {
            // Handle conflict
            try await handleConflict(
                item: item,
                serverData: serverData
            )
        }
    }
}
```

## Conflict Resolution

### Conflict Detection

```swift
struct ConflictInfo {
    let localVersion: Int
    let serverVersion: Int
    let localChangedAt: Date
    let serverChangedAt: Date
    let conflictingFields: [String]
}

extension SyncQueueManager {
    private func detectConflict(
        local: Data,
        server: Data
    ) throws -> ConflictInfo? {
        let localEntity = try JSONDecoder().decode(
            VersionedEntity.self,
            from: local
        )
        let serverEntity = try JSONDecoder().decode(
            VersionedEntity.self,
            from: server
        )
        
        if localEntity.version < serverEntity.version {
            // Find conflicting fields
            let conflicts = findConflictingFields(
                local: localEntity,
                server: serverEntity
            )
            
            if !conflicts.isEmpty {
                return ConflictInfo(
                    localVersion: localEntity.version,
                    serverVersion: serverEntity.version,
                    localChangedAt: localEntity.updatedAt,
                    serverChangedAt: serverEntity.updatedAt,
                    conflictingFields: conflicts
                )
            }
        }
        
        return nil
    }
}
```

### Conflict Resolution Strategies

```swift
enum ConflictResolutionStrategy {
    case serverWins      // Accept server version
    case clientWins      // Keep local version
    case merge           // Merge non-conflicting fields
    case manual          // Require user intervention
}

final class ConflictResolver {
    func resolveConflict(
        entityType: String,
        conflict: ConflictInfo,
        localData: Data,
        serverData: Data
    ) async throws -> ConflictResolution {
        // Determine strategy based on entity type and conflict
        let strategy = determineStrategy(
            entityType: entityType,
            conflict: conflict
        )
        
        switch strategy {
        case .serverWins:
            return .acceptServer(serverData)
            
        case .clientWins:
            return .keepLocal(localData)
            
        case .merge:
            let merged = try mergeData(
                local: localData,
                server: serverData,
                conflicts: conflict.conflictingFields
            )
            return .merged(merged)
            
        case .manual:
            return try await requestUserResolution(
                conflict: conflict,
                localData: localData,
                serverData: serverData
            )
        }
    }
    
    private func determineStrategy(
        entityType: String,
        conflict: ConflictInfo
    ) -> ConflictResolutionStrategy {
        // Health metrics: server wins (most accurate)
        if entityType == "HealthMetric" {
            return .serverWins
        }
        
        // User preferences: client wins
        if entityType == "UserPreference" {
            return .clientWins
        }
        
        // Notes/comments: merge if possible
        if entityType == "Note" && conflict.conflictingFields.count == 1 {
            return .merge
        }
        
        // Default: manual resolution
        return .manual
    }
}
```

### Manual Conflict Resolution UI

```swift
struct ConflictResolutionView: View {
    let conflict: ConflictInfo
    let localData: HealthData
    let serverData: HealthData
    @Binding var resolution: ConflictResolution?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sync Conflict Detected")
                .font(.headline)
            
            Text("The following data has been modified both locally and on the server:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Show conflicting fields
            ForEach(conflict.conflictingFields, id: \.self) { field in
                ConflictFieldView(
                    fieldName: field,
                    localValue: localData[field],
                    serverValue: serverData[field]
                )
            }
            
            // Resolution options
            VStack(spacing: 12) {
                Button("Keep My Version") {
                    resolution = .keepLocal(localData)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Use Server Version") {
                    resolution = .acceptServer(serverData)
                }
                .buttonStyle(.bordered)
                
                Button("Merge Changes") {
                    resolution = .merge(localData, serverData)
                }
                .buttonStyle(.bordered)
                .disabled(!canMerge)
            }
        }
        .padding()
    }
}
```

## Offline Data Management

### Local Storage Strategy

```swift
// OfflineDataManager.swift
@Observable
final class OfflineDataManager {
    private let modelContext: ModelContext
    private let cacheManager: CacheManager
    
    // Storage limits
    private let maxOfflineDataSize: Int = 100_000_000 // 100MB
    private let maxOfflineDataAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    func storeForOffline<T: Codable & PersistentModel>(
        _ entity: T,
        priority: OfflinePriority = .normal
    ) throws {
        // Check storage limits
        try enforceStorageLimits()
        
        // Mark for offline availability
        entity.isAvailableOffline = true
        entity.offlinePriority = priority
        entity.lastAccessedAt = Date()
        
        try modelContext.save()
    }
    
    func pruneOfflineData() async throws {
        // Remove old data
        let cutoffDate = Date().addingTimeInterval(-maxOfflineDataAge)
        
        let descriptor = FetchDescriptor<OfflineEntity>(
            predicate: #Predicate { entity in
                entity.lastAccessedAt < cutoffDate &&
                entity.offlinePriority != .critical
            }
        )
        
        let oldEntities = try modelContext.fetch(descriptor)
        
        for entity in oldEntities {
            entity.isAvailableOffline = false
        }
        
        try modelContext.save()
    }
}

enum OfflinePriority: Int, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3  // Never removed
}
```

### Optimistic Updates

```swift
// OptimisticUpdateManager.swift
@Observable
final class OptimisticUpdateManager {
    private let modelContext: ModelContext
    private let syncQueue: SyncQueueManager
    
    func performOptimisticUpdate<T: PersistentModel>(
        entity: T,
        update: (T) -> Void
    ) async throws {
        // Create snapshot for rollback
        let snapshot = entity.createSnapshot()
        
        // Apply update immediately
        update(entity)
        entity.lastModifiedLocally = Date()
        entity.syncStatus = .pendingSync
        
        // Save to local store
        try modelContext.save()
        
        // Queue for sync
        try syncQueue.enqueue(
            operation: .update,
            entity: entity,
            entityType: String(describing: T.self),
            entityId: entity.id
        )
        
        // Store snapshot for potential rollback
        storeSnapshot(entityId: entity.id, snapshot: snapshot)
    }
    
    func rollbackOptimisticUpdate(entityId: String) throws {
        guard let snapshot = retrieveSnapshot(entityId: entityId) else {
            throw SyncError.snapshotNotFound
        }
        
        // Restore from snapshot
        snapshot.restore()
        try modelContext.save()
        
        // Remove from sync queue
        syncQueue.cancelOperation(entityId: entityId)
    }
}
```

## Background Sync

### Background Task Management

```swift
// BackgroundSyncManager.swift
final class BackgroundSyncManager {
    private let syncQueue: SyncQueueManager
    private let healthKitSync: HealthKitSyncService
    
    func scheduleBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.clarity.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
        
        scheduleNextSync()
    }
    
    private func handleBackgroundSync(task: BGProcessingTask) {
        // Create background operation
        let syncOperation = Task {
            do {
                // Sync pending queue items
                await syncQueue.processQueue()
                
                // Sync HealthKit data
                await healthKitSync.performBackgroundSync()
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            
            // Schedule next sync
            scheduleNextSync()
        }
        
        // Handle expiration
        task.expirationHandler = {
            syncOperation.cancel()
        }
    }
    
    private func scheduleNextSync() {
        let request = BGProcessingTaskRequest(
            identifier: "com.clarity.sync"
        )
        
        // Schedule for next opportunity
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

### Silent Push Sync

```swift
// SilentPushHandler.swift
final class SilentPushHandler {
    private let syncQueue: SyncQueueManager
    
    func handleSilentPush(
        userInfo: [AnyHashable: Any],
        completion: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Extract sync instructions
        guard let syncData = userInfo["sync"] as? [String: Any],
              let syncType = syncData["type"] as? String else {
            completion(.noData)
            return
        }
        
        Task {
            do {
                switch syncType {
                case "full":
                    await performFullSync()
                case "partial":
                    let entities = syncData["entities"] as? [String] ?? []
                    await performPartialSync(entities: entities)
                case "urgent":
                    await performUrgentSync()
                default:
                    break
                }
                
                completion(.newData)
            } catch {
                completion(.failed)
            }
        }
    }
}
```

## Sync Status UI

### Sync Status View

```swift
struct SyncStatusView: View {
    @Environment(\.syncQueue) private var syncQueue
    @State private var showDetails = false
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Pending count
            if syncQueue.pendingCount > 0 {
                Text("(\(syncQueue.pendingCount))")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .onTapGesture {
            showDetails.toggle()
        }
        .sheet(isPresented: $showDetails) {
            SyncDetailsView()
        }
    }
    
    private var statusColor: Color {
        if !syncQueue.isOnline {
            return .gray
        } else if syncQueue.isProcessing {
            return .orange
        } else if syncQueue.pendingCount > 0 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if !syncQueue.isOnline {
            return "Offline"
        } else if syncQueue.isProcessing {
            return "Syncing..."
        } else if syncQueue.pendingCount > 0 {
            return "Pending sync"
        } else {
            return "Synced"
        }
    }
}
```

### Sync Progress View

```swift
struct SyncProgressView: View {
    @ObservedObject var syncProgress: SyncProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall progress
            HStack {
                Text("Syncing data...")
                    .font(.headline)
                
                Spacer()
                
                Text("\(syncProgress.completedItems)/\(syncProgress.totalItems)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            ProgressView(value: syncProgress.progress)
                .progressViewStyle(.linear)
            
            // Current operation
            if let currentOperation = syncProgress.currentOperation {
                Text(currentOperation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Error state
            if let error = syncProgress.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
```

## Testing Offline Sync

```swift
// OfflineSyncTests.swift
final class OfflineSyncTests: XCTestCase {
    var syncQueue: SyncQueueManager!
    var mockNetwork: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkService()
        syncQueue = SyncQueueManager(
            modelContext: createTestContext(),
            networkService: mockNetwork,
            conflictResolver: ConflictResolver()
        )
    }
    
    func test_offlineOperation_shouldQueueForSync() throws {
        // Given
        mockNetwork.isOffline = true
        let healthData = HealthData.mock()
        
        // When
        try syncQueue.enqueue(
            operation: .create,
            entity: healthData,
            entityType: "HealthData",
            entityId: healthData.id
        )
        
        // Then
        XCTAssertEqual(syncQueue.pendingCount, 1)
        XCTAssertFalse(syncQueue.isProcessing)
    }
    
    func test_networkReconnection_shouldProcessQueue() async throws {
        // Given
        mockNetwork.isOffline = true
        try syncQueue.enqueue(
            operation: .create,
            entity: HealthData.mock(),
            entityType: "HealthData",
            entityId: "123"
        )
        
        // When
        mockNetwork.isOffline = false
        syncQueue.handleNetworkChange(isOnline: true)
        
        // Wait for processing
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Then
        XCTAssertEqual(syncQueue.pendingCount, 0)
        XCTAssertTrue(mockNetwork.requestCalled)
    }
    
    func test_conflictResolution_shouldMergeData() async throws {
        // Given
        let localData = HealthData(id: "123", value: 100, version: 1)
        let serverData = HealthData(id: "123", value: 200, version: 2)
        
        mockNetwork.simulateConflict(
            localData: localData,
            serverData: serverData
        )
        
        // When
        try syncQueue.enqueue(
            operation: .update,
            entity: localData,
            entityType: "HealthData",
            entityId: localData.id
        )
        
        await syncQueue.processQueue()
        
        // Then
        let resolved = try fetchEntity(id: "123")
        XCTAssertEqual(resolved.version, 3) // Merged version
    }
}
```

## Performance Optimization

### Batch Sync Operations

```swift
extension SyncQueueManager {
    func enqueueBatch<T: Codable>(
        operations: [(SyncOperationType, T, String)]
    ) throws {
        // Group by operation type
        let grouped = Dictionary(grouping: operations) { $0.0 }
        
        for (operationType, items) in grouped {
            let batchPayload = items.map { ($0.1, $0.2) }
            
            let batchItem = SyncQueueItem(
                operationType: .batchUpdate,
                entityType: "Batch",
                entityId: UUID().uuidString,
                payload: try JSONEncoder().encode(batchPayload)
            )
            
            modelContext.insert(batchItem)
        }
        
        try modelContext.save()
        pendingCount += grouped.count
    }
}
```

### Delta Sync

```swift
struct DeltaSync {
    let entityId: String
    let changes: [FieldChange]
    let baseVersion: Int
}

struct FieldChange {
    let field: String
    let oldValue: Any?
    let newValue: Any?
}

extension SyncQueueManager {
    func enqueueDelta(
        entity: any PersistentModel,
        changes: [FieldChange]
    ) throws {
        let delta = DeltaSync(
            entityId: entity.id,
            changes: changes,
            baseVersion: entity.version
        )
        
        // Only sync changed fields
        try enqueue(
            operation: .update,
            entity: delta,
            entityType: "Delta",
            entityId: entity.id
        )
    }
}
```

## Monitoring & Metrics

```swift
struct SyncMetrics {
    var totalSynced: Int = 0
    var failedSyncs: Int = 0
    var averageSyncTime: TimeInterval = 0
    var lastSyncDate: Date?
    var dataTransferred: Int = 0
    var conflictsResolved: Int = 0
}
```

## ⚠️ Critical Implementation Notes

1. **Always persist sync queue** - Use SwiftData to survive app restarts
2. **Handle auth token refresh** - Token may expire during long offline periods
3. **Implement exponential backoff** - Don't hammer server after reconnection
4. **Monitor storage usage** - Clean up old offline data regularly
5. **Test airplane mode** - Most common offline scenario
6. **Handle partial sync failures** - Some items may succeed while others fail

---

✅ This offline sync architecture ensures CLARITY works seamlessly offline while maintaining data integrity and providing excellent user experience.