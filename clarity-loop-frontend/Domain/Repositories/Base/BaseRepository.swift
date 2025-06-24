import Foundation
import Observation
import SwiftData

// MARK: - Base Repository Protocol

protocol BaseRepository: AnyObject {
    associatedtype Model: PersistentModel

    // MARK: - Properties

    var modelContext: ModelContext { get }

    // MARK: - CRUD Operations

    func create(_ model: Model) async throws
    func read(by id: PersistentIdentifier) async throws -> Model?
    func update(_ model: Model) async throws
    func delete(_ model: Model) async throws
    func deleteAll() async throws

    // MARK: - Batch Operations

    func createBatch(_ models: [Model]) async throws
    func updateBatch(_ models: [Model]) async throws
    func deleteBatch(_ models: [Model]) async throws

    // MARK: - Query Operations

    func fetch(descriptor: FetchDescriptor<Model>) async throws -> [Model]
    func fetchAll() async throws -> [Model]
    func count(where predicate: Predicate<Model>?) async throws -> Int

    // MARK: - Sync Operations

    func sync() async throws
    func syncBatch(_ models: [Model]) async throws
    func resolveSyncConflicts(for models: [Model]) async throws
}

// MARK: - Default Implementations

extension BaseRepository {
    // MARK: - Default CRUD

    func create(_ model: Model) async throws {
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ model: Model) async throws {
        // SwiftData automatically tracks changes
        try modelContext.save()
    }

    func delete(_ model: Model) async throws {
        modelContext.delete(model)
        try modelContext.save()
    }

    func deleteAll() async throws {
        let models = try await fetchAll()
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    // MARK: - Default Batch Operations

    func createBatch(_ models: [Model]) async throws {
        for model in models {
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func updateBatch(_ models: [Model]) async throws {
        // SwiftData automatically tracks changes
        try modelContext.save()
    }

    func deleteBatch(_ models: [Model]) async throws {
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    // MARK: - Default Query Operations

    func fetch(descriptor: FetchDescriptor<Model>) async throws -> [Model] {
        try modelContext.fetch(descriptor)
    }

    func fetchAll() async throws -> [Model] {
        let descriptor = FetchDescriptor<Model>()
        return try modelContext.fetch(descriptor)
    }

    func count(where predicate: Predicate<Model>? = nil) async throws -> Int {
        var descriptor = FetchDescriptor<Model>()
        descriptor.predicate = predicate
        return try modelContext.fetchCount(descriptor)
    }
}

// MARK: - Observable Base Repository

@Observable
class ObservableBaseRepository<Model: PersistentModel>: BaseRepository {
    // MARK: - Properties

    let modelContext: ModelContext

    // Reactive properties
    private(set) var isLoading = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    private(set) var pendingSyncCount = 0

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - BaseRepository Protocol Requirements

    func read(by id: PersistentIdentifier) async throws -> Model? {
        // SwiftData doesn't directly support fetching by PersistentIdentifier
        // We need to fetch all and find the matching one
        let all = try await fetchAll()
        return all.first { $0.persistentModelID == id }
    }

    // MARK: - Sync Operations (Must be overridden)

    func sync() async throws {
        fatalError("Subclasses must implement sync()")
    }

    func syncBatch(_ models: [Model]) async throws {
        fatalError("Subclasses must implement syncBatch(_:)")
    }

    func resolveSyncConflicts(for models: [Model]) async throws {
        fatalError("Subclasses must implement resolveSyncConflicts(for:)")
    }

    // MARK: - Protected Methods for Subclasses

    @MainActor
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    @MainActor
    func setSyncError(_ error: Error?) {
        syncError = error
    }

    @MainActor
    func updateSyncStatus(pendingCount: Int) {
        pendingSyncCount = pendingCount
        if pendingCount == 0 {
            lastSyncDate = Date()
            syncError = nil
        }
    }
}

// MARK: - Repository Error

enum RepositoryError: LocalizedError {
    case entityNotFound
    case syncFailed(Error)
    case conflictResolutionFailed
    case batchOperationFailed(Error)
    case invalidPredicate

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "Entity not found"
        case let .syncFailed(error):
            return "Sync failed: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        case let .batchOperationFailed(error):
            return "Batch operation failed: \(error.localizedDescription)"
        case .invalidPredicate:
            return "Invalid query predicate"
        }
    }
}

// MARK: - Sync Protocol

protocol SyncableModel: PersistentModel {
    var syncStatus: SyncStatus { get set }
    var lastSyncedAt: Date? { get set }
    var syncError: String? { get set }
}

// MARK: - Predicate Builders

enum RepositoryPredicates {
    static func pendingSync<T: SyncableModel>() -> Predicate<T> {
        let pendingStatus = SyncStatus.pending.rawValue
        let failedStatus = SyncStatus.failed.rawValue

        return #Predicate<T> { model in
            model.syncStatus.rawValue == pendingStatus || model.syncStatus.rawValue == failedStatus
        }
    }

    static func needsSync<T: SyncableModel>(since date: Date) -> Predicate<T> {
        #Predicate<T> { model in
            model.lastSyncedAt == nil || model.lastSyncedAt! < date
        }
    }

    static func withSyncError<T: SyncableModel>() -> Predicate<T> {
        #Predicate<T> { model in
            model.syncError != nil
        }
    }
}
