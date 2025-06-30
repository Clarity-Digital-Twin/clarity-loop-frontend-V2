//
//  BaseViewModel.swift
//  clarity-loop-frontend-v2
//
//  Base class for ViewModels with @Observable and ViewState support
//

import Foundation
import Observation

/// Base class for ViewModels with built-in ViewState management
///
/// BaseViewModel provides a consistent pattern for managing async state
/// in ViewModels. It uses the @Observable macro for SwiftUI integration
/// and follows the template method pattern for data loading.
///
/// Usage:
/// ```swift
/// @Observable
/// final class UserListViewModel: BaseViewModel<[User]> {
///     private let userRepository: UserRepositoryProtocol
///     
///     init(userRepository: UserRepositoryProtocol) {
///         self.userRepository = userRepository
///         super.init()
///     }
///     
///     override func loadData() async throws -> [User]? {
///         return try await userRepository.list()
///     }
/// }
/// ```
@Observable
open class BaseViewModel<DataType: Equatable & Sendable>: BaseViewModelProtocol {
    
    // MARK: - Properties
    
    /// Current state of the view
    public internal(set) var viewState: ViewState<DataType> = .idle
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Loads data and updates the view state
    ///
    /// This method sets the state to loading, calls the loadData() template method,
    /// and updates the state based on the result.
    @MainActor
    public func load() async {
        viewState = .loading
        
        do {
            if let data = try await loadData() {
                viewState = .success(data)
            } else {
                viewState = .empty
            }
        } catch {
            viewState = .error(error)
        }
    }
    
    /// Reloads data by calling load again
    @MainActor
    public func reload() async {
        await load()
    }
    
    /// Handles an error by updating the view state
    /// - Parameter error: The error to handle
    @MainActor
    public func handleError(_ error: Error) {
        viewState = .error(error)
    }
    
    /// Sets the view state to success with data
    /// - Parameter data: The data to set
    @MainActor
    public func setSuccess(_ data: DataType) {
        viewState = .success(data)
    }
    
    /// Sets the view state to empty
    @MainActor
    public func setEmpty() {
        viewState = .empty
    }
    
    /// Resets the view state to idle
    @MainActor
    public func reset() {
        viewState = .idle
    }
    
    // MARK: - Template Methods
    
    /// Override this method to load data asynchronously
    ///
    /// This is a template method that subclasses must override to provide
    /// their specific data loading implementation.
    ///
    /// - Returns: The loaded data, or nil if no data is available
    /// - Throws: Any error that occurs during data loading
    @MainActor
    open func loadData() async throws -> DataType? {
        // Default implementation returns nil
        // Subclasses should override this method to provide actual data loading
        return nil
    }
    
    // MARK: - Convenience Properties
    
    /// Whether the view is currently loading
    public var isLoading: Bool {
        if case .loading = viewState { return true }
        return false
    }
    
    /// Whether the view has successfully loaded data
    public var isSuccess: Bool {
        if case .success = viewState { return true }
        return false
    }
    
    /// Whether the view encountered an error
    public var isError: Bool {
        if case .error = viewState { return true }
        return false
    }
    
    /// Whether the view has no data to display
    public var isEmpty: Bool {
        if case .empty = viewState { return true }
        return false
    }
    
    /// The current value if in success state
    public var value: DataType? {
        if case .success(let data) = viewState { return data }
        return nil
    }
    
    /// The current error if in error state
    public var error: Error? {
        if case .error(let error) = viewState { return error }
        return nil
    }
}
