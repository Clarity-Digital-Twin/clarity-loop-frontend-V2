import Foundation
import Observation
import SwiftData

/// Base view model providing common functionality for all view models
@Observable
open class BaseViewModel {
    // MARK: - Properties

    /// Indicates if any async operation is in progress
    public var isLoading = false

    /// Current error if any operation failed
    public var currentError: Error?

    /// ModelContext for SwiftData operations
    public let modelContext: ModelContext

    // MARK: - Initialization

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Error Handling

    /// Handles errors in a consistent way across all view models
    public func handle(error: Error) {
        currentError = error
        isLoading = false

        // Log error for debugging
        print("[BaseViewModel] Error: \(error)")

        // Additional error handling can be added here
        // e.g., analytics, crash reporting
    }

    /// Clears the current error
    public func clearError() {
        currentError = nil
    }

    // MARK: - Loading State Management

    /// Executes an async operation with automatic loading state management
    public func performOperation<T>(
        operation: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) async {
        isLoading = true
        clearError()

        do {
            let result = try await operation()
            await MainActor.run {
                isLoading = false
                onSuccess?(result)
            }
        } catch {
            await MainActor.run {
                handle(error: error)
                onError?(error)
            }
        }
    }

    /// Executes an async operation that updates ViewState
    func performStateOperation<T: Equatable>(
        currentState: ViewState<T>,
        operation: () async throws -> T
    ) async -> ViewState<T> {
        clearError()

        do {
            let result = try await operation()
            return result is any Collection && (result as! any Collection).isEmpty ? .empty : .loaded(result)
        } catch {
            handle(error: error)
            return .error(error)
        }
    }

    // MARK: - SwiftData Helpers

    /// Saves the model context with error handling
    public func saveContext() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    /// Performs a SwiftData operation with error handling
    public func performDataOperation(
        operation: () throws -> Void
    ) {
        do {
            try operation()
            try saveContext()
        } catch {
            handle(error: error)
        }
    }

    // MARK: - Retry Logic

    /// Retries an operation with exponential backoff
    public func retryOperation<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(
            domain: "BaseViewModel",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
        )
    }
}

// MARK: - Repository Integration

extension BaseViewModel {
    /// Syncs data using a repository with loading state management
    func syncWithRepository(
        repository: some BaseRepository,
        onCompletion: (() -> Void)? = nil
    ) async {
        await performOperation(
            operation: {
                try await repository.sync()
            },
            onSuccess: { _ in
                onCompletion?()
            }
        )
    }

    /// Fetches data from repository with automatic state management
    func fetchFromRepository<T: BaseRepository, Model>(
        repository: T,
        fetch: (T) async throws -> [Model]
    ) async -> [Model] {
        do {
            return try await fetch(repository)
        } catch {
            handle(error: error)
            return []
        }
    }
}
