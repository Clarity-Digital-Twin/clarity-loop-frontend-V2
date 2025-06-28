//
//  MockBaseViewModel.swift
//  clarity-loop-frontend-v2
//
//  Mock implementation of BaseViewModel for testing purposes
//

import Foundation
import Observation

/// Mock BaseViewModel for testing view behavior with different states
///
/// This mock allows direct manipulation of viewState and provides
/// hooks to test ViewModel interactions in unit tests.
///
/// Usage:
/// ```swift
/// let mockViewModel = MockBaseViewModel<[User]>()
/// mockViewModel.simulateLoading()
/// XCTAssertTrue(mockViewModel.isLoading)
/// 
/// mockViewModel.simulateSuccess([user1, user2])
/// XCTAssertEqual(mockViewModel.value?.count, 2)
/// ```
@Observable
public final class MockBaseViewModel<DataType: Equatable & Sendable>: BaseViewModel<DataType> {
    
    // MARK: - Test Properties
    
    /// Number of times load() was called
    public private(set) var loadCallCount = 0
    
    /// Number of times reload() was called
    public private(set) var reloadCallCount = 0
    
    /// Number of times handleError() was called
    public private(set) var handleErrorCallCount = 0
    
    /// Last error passed to handleError()
    public private(set) var lastHandledError: Error?
    
    /// Mock data to return from loadData()
    public var mockData: DataType?
    
    /// Mock error to throw from loadData()
    public var mockError: Error?
    
    /// Delay to simulate async loading (in seconds)
    public var mockDelay: TimeInterval = 0
    
    /// Whether loadData() should return nil (for empty state)
    public var shouldReturnNil = false
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - Override Methods
    
    @MainActor
    public override func load() async {
        loadCallCount += 1
        await super.load()
    }
    
    @MainActor
    public override func reload() async {
        reloadCallCount += 1
        await super.reload()
    }
    
    @MainActor
    public override func handleError(_ error: Error) {
        handleErrorCallCount += 1
        lastHandledError = error
        super.handleError(error)
    }
    
    @MainActor
    public override func loadData() async throws -> DataType? {
        // Simulate network delay if configured
        if mockDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        // Throw error if configured
        if let error = mockError {
            throw error
        }
        
        // Return nil if configured for empty state
        if shouldReturnNil {
            return nil
        }
        
        // Return mock data
        return mockData
    }
    
    // MARK: - Test Helper Methods
    
    /// Directly set the view state to loading
    @MainActor
    public func simulateLoading() {
        viewState = .loading
    }
    
    /// Directly set the view state to success with data
    @MainActor
    public func simulateSuccess(_ data: DataType) {
        viewState = .success(data)
    }
    
    /// Directly set the view state to error
    @MainActor
    public func simulateError(_ error: Error) {
        viewState = .error(error)
    }
    
    /// Directly set the view state to empty
    @MainActor
    public func simulateEmpty() {
        viewState = .empty
    }
    
    /// Directly set the view state to idle
    @MainActor
    public func simulateIdle() {
        viewState = .idle
    }
    
    /// Reset all counters and state
    @MainActor
    public func resetMock() {
        loadCallCount = 0
        reloadCallCount = 0
        handleErrorCallCount = 0
        lastHandledError = nil
        mockData = nil
        mockError = nil
        mockDelay = 0
        shouldReturnNil = false
        viewState = .idle
    }
}

// MARK: - Test Error

/// Sample error for testing
public enum MockViewModelError: Error, Equatable {
    case testError
    case networkError
    case validationError(String)
}