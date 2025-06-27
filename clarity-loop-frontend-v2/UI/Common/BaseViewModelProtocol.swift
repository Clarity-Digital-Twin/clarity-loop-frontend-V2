//
//  BaseViewModelProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol defining the contract for ViewModels with ViewState support
//

import Foundation

/// Protocol defining the core functionality for ViewModels with ViewState support
///
/// This protocol ensures all ViewModels have consistent state management
/// and loading behavior, making them testable and predictable.
public protocol BaseViewModelProtocol: AnyObject {
    /// The type of data managed by this ViewModel
    associatedtype DataType: Equatable & Sendable
    
    /// Current state of the view
    var viewState: ViewState<DataType> { get }
    
    /// Loads data and updates the view state
    func load() async
    
    /// Reloads data by calling load again
    func reload() async
    
    /// Handles an error by updating the view state
    /// - Parameter error: The error to handle
    @MainActor
    func handleError(_ error: Error)
    
    /// Sets the view state to success with data
    /// - Parameter data: The data to set
    @MainActor
    func setSuccess(_ data: DataType)
    
    /// Sets the view state to empty
    @MainActor
    func setEmpty()
    
    /// Resets the view state to idle
    @MainActor
    func reset()
    
    // MARK: - Convenience Properties
    
    /// Whether the view is currently loading
    var isLoading: Bool { get }
    
    /// Whether the view has successfully loaded data
    var isSuccess: Bool { get }
    
    /// Whether the view encountered an error
    var isError: Bool { get }
    
    /// Whether the view has no data to display
    var isEmpty: Bool { get }
    
    /// The current value if in success state
    var value: DataType? { get }
    
    /// The current error if in error state
    var error: Error? { get }
}