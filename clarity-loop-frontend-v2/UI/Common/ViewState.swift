//
//  ViewState.swift
//  clarity-loop-frontend-v2
//
//  Generic pattern for handling async UI states consistently
//

import Foundation

/// Represents the state of an async view operation
///
/// ViewState provides a consistent pattern for handling different states
/// of async operations in SwiftUI views. It encapsulates common states
/// like loading, success, error, and empty results.
///
/// Usage:
/// ```swift
/// @Observable
/// final class MyViewModel {
///     private(set) var state: ViewState<[Item]> = .idle
///     
///     func loadData() async {
///         state = .loading
///         do {
///             let items = try await repository.fetchItems()
///             state = items.isEmpty ? .empty : .success(items)
///         } catch {
///             state = .error(error)
///         }
///     }
/// }
/// ```
public enum ViewState<T: Equatable>: Equatable, Sendable where T: Sendable {
    /// Initial state before any operation
    case idle
    
    /// Loading/fetching data
    case loading
    
    /// Operation completed successfully with data
    case success(T)
    
    /// Operation failed with an error
    case error(Error)
    
    /// Operation completed but returned no data
    case empty
    
    // MARK: - Equatable
    
    public static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.empty, .empty):
            return true
            
        case (.success(let lhsValue), .success(let rhsValue)):
            return lhsValue == rhsValue
            
        case (.error(let lhsError), .error(let rhsError)):
            // Compare error descriptions since Error isn't Equatable
            return String(describing: lhsError) == String(describing: rhsError)
            
        default:
            return false
        }
    }
}

// MARK: - Helper Properties

public extension ViewState {
    /// Returns true if the state is idle
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    /// Returns true if the state is loading
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    /// Returns true if the state is success
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    /// Returns true if the state is error
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    /// Returns true if the state is empty
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
    
    /// Returns the success value if available
    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    /// Returns the error if available
    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}

// MARK: - Transformation

public extension ViewState {
    /// Transform the success value to a different type
    ///
    /// - Parameter transform: Closure to transform the value
    /// - Returns: A new ViewState with the transformed value
    func map<U: Equatable & Sendable>(_ transform: (T) -> U) -> ViewState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .success(let value):
            return .success(transform(value))
        case .error(let error):
            return .error(error)
        case .empty:
            return .empty
        }
    }
}