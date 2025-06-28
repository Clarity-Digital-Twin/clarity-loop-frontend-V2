//
//  AsyncTestCase.swift
//  clarity-loop-frontend-v2Tests
//
//  Specialized test case for testing asynchronous code with Swift concurrency
//

import XCTest
@testable import ClarityCore

/// Base test case for async/await testing
open class AsyncTestCase: BaseUnitTestCase {
    
    // MARK: - Async Setup/Teardown
    
    /// Override for async setup
    open func asyncSetUp() async throws {
        // Subclasses can override
    }
    
    /// Override for async teardown
    open func asyncTearDown() async throws {
        // Subclasses can override
    }
    
    // MARK: - Async Assertions
    
    /// Assert async operation succeeds
    public func assertAsync<T: Sendable>(
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line,
        _ operation: @Sendable @escaping () async throws -> T
    ) async {
        do {
            _ = try await withTimeout(timeout, file: file, line: line) {
                try await operation()
            }
        } catch {
            XCTFail("Async operation failed: \(error)", file: file, line: line)
        }
    }
    
    /// Assert async operation throws error
    public func assertAsyncThrows<E: Error>(
        error expectedError: E? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line,
        _ operation: @Sendable @escaping () async throws -> Void
    ) async where E: Equatable {
        do {
            _ = try await withTimeout(timeout, file: file, line: line) {
                try await operation()
            }
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch let thrownError {
            if let expectedError = expectedError {
                if let error = thrownError as? E {
                    XCTAssertEqual(error, expectedError, file: file, line: line)
                } else {
                    XCTFail("Wrong error type: \(thrownError)", file: file, line: line)
                }
            }
            // If no specific error expected, just verify something was thrown
        }
    }
    
    /// Assert async operation throws any error
    public func assertAsyncThrows(
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line,
        _ operation: @Sendable @escaping () async throws -> Void
    ) async {
        await assertAsyncThrows(error: nil as NSError?, timeout: timeout, file: file, line: line, operation)
    }
    
    // MARK: - Expectation Wrappers
    
    /// Wait for async operation with completion handler
    public func waitForAsync<T: Sendable>(
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line,
        _ operation: @Sendable (@escaping @Sendable (T) -> Void) -> Void
    ) async -> T? {
        await withCheckedContinuation { continuation in
            let box = Box<T?>(value: nil)
            let expectation = self.expectation(description: "Async operation")
            
            operation { value in
                box.value = value
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: timeout)
            continuation.resume(returning: box.value)
        }
    }
    
    // MARK: - Observable Helpers
    
    /// Wait for @Observable property to change
    public func waitForObservableChange<Root: AnyObject, Value: Equatable>(
        on object: Root,
        keyPath: KeyPath<Root, Value>,
        expectedValue: Value,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if object[keyPath: keyPath] == expectedValue {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        XCTFail(
            "Observable property did not change to expected value within timeout",
            file: file,
            line: line
        )
    }
    
    /// Wait for @Observable property to satisfy condition
    public func waitForObservable<Root: AnyObject, Value>(
        on object: Root,
        keyPath: KeyPath<Root, Value>,
        condition: (Value) -> Bool,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if condition(object[keyPath: keyPath]) {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        XCTFail(
            "Observable property did not satisfy condition within timeout",
            file: file,
            line: line
        )
    }
    
    // MARK: - Timeout Management
    
    /// Execute async operation with timeout
    public func withTimeout<T: Sendable>(
        _ timeout: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            
            throw TimeoutError()
        }
    }
    
    /// Retry async operation with delays
    public func retryAsync<T>(
        attempts: Int = 3,
        delay: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < attempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "AsyncTestCase", code: -1)
    }
}

// MARK: - Task Extension

/// Error thrown when an async operation times out
struct TimeoutError: Error, LocalizedError {
    let errorDescription: String? = "Operation timed out"
}

/// Box to wrap mutable values for sendable contexts
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) {
        self.value = value
    }
}
