//
//  ViewState.swift
//  clarity-loop-frontend-v2
//
//  Generic view state for handling async operations in ViewModels
//

import Foundation

/// Represents the state of an async operation in the UI
public enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case success(T)
    case error(String)
    
    /// Returns true if the state is loading
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// Returns the success value if available
    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    /// Returns the error message if available
    public var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}