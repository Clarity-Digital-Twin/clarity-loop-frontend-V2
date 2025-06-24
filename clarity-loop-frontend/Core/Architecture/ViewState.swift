import Foundation

/// A generic enum to represent the state of a view that loads data asynchronously.
/// This provides a consistent way to handle loading, error, and content states across different features.
public enum ViewState<T: Equatable>: Equatable {
    /// The view is idle and has not yet started loading.
    case idle

    /// The view is currently loading data.
    case loading

    /// The view has successfully loaded the data.
    case loaded(T)

    /// The view loaded successfully, but there is no data to display.
    case empty

    /// The view encountered an error while loading data.
    case error(Error)

    // MARK: - Computed Properties

    /// Returns true if the view is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Returns true if the view has loaded successfully
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// Returns true if the view has an error
    var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Returns true if the view is empty
    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }

    /// Returns the loaded value if available
    var value: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }

    /// Returns the error if available
    var error: Error? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }

    /// Returns a user-friendly error message for display
    var errorMessage: String? {
        guard case let .error(error) = self else { return nil }

        // Handle specific error types with custom messages
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }

        // Default to localized description
        return error.localizedDescription
    }

    // MARK: - Convenience Methods

    /// Maps the loaded value to a new type
    func map<U: Equatable>(_ transform: (T) -> U) -> ViewState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case let .loaded(value):
            return .loaded(transform(value))
        case .empty:
            return .empty
        case let .error(error):
            return .error(error)
        }
    }

    /// Maps the loaded value to a new ViewState
    func flatMap<U: Equatable>(_ transform: (T) -> ViewState<U>) -> ViewState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case let .loaded(value):
            return transform(value)
        case .empty:
            return .empty
        case let .error(error):
            return .error(error)
        }
    }
}

// MARK: - Equatable Conformance for Error

extension ViewState {
    public static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty):
            return true
        case let (.loaded(lhsValue), .loaded(rhsValue)):
            return lhsValue == rhsValue
        case let (.error(lhsError), .error(rhsError)):
            // Compare errors by domain and code for proper equality
            let lhsNSError = lhsError as NSError
            let rhsNSError = rhsError as NSError
            return lhsNSError.domain == rhsNSError.domain &&
                lhsNSError.code == rhsNSError.code
        default:
            return false
        }
    }
}

// MARK: - Convenience Methods

extension ViewState {
    /// Creates a success state, automatically handling empty collections
    public static func success(_ value: T) -> ViewState where T: Collection {
        value.isEmpty ? .empty : .loaded(value)
    }

    /// Checks if this is a specific error type
    public func isError<E: Error>(ofType type: E.Type) -> Bool {
        guard case let .error(error) = self else { return false }
        return error is E
    }

    /// Gets the error cast to a specific type if available
    public func error<E: Error>(as type: E.Type) -> E? {
        guard case let .error(error) = self else { return nil }
        return error as? E
    }
}
