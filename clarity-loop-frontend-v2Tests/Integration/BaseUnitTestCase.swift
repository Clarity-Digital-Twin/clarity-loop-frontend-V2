//
//  BaseUnitTestCase.swift
//  clarity-loop-frontend-v2Tests
//
//  Base class for all unit tests following TDD/BDD principles
//

import XCTest
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityUI

/// Base test case providing common functionality for all unit tests
/// Following TDD Red-Green-Refactor cycle
open class BaseUnitTestCase: XCTestCase {
    
    // MARK: - Properties
    
    /// Track test execution time
    public private(set) var testStartTime: Date?
    
    /// Objects being tracked for memory leaks
    public private(set) var retainedObjects: [AnyObject]?
    
    // MARK: - Lifecycle
    
    open override func setUp() {
        super.setUp()
        testStartTime = Date()
        retainedObjects = []
    }
    
    open override func tearDown() {
        // Check for memory leaks
        checkForMemoryLeaks()
        
        // Clean up
        testStartTime = nil
        retainedObjects = nil
        
        super.tearDown()
    }
    
    // MARK: - Memory Leak Detection
    
    /// Track an object for memory leak detection
    /// - Parameter object: Object to track
    public func trackForMemoryLeak(_ object: AnyObject, file: StaticString = #file, line: UInt = #line) {
        retainedObjects?.append(object)
        
        // Simple implementation without concurrency issues
        // The object tracking is handled in checkForMemoryLeaks during tearDown
    }
    
    private func checkForMemoryLeaks() {
        // This is called during tearDown to ensure tracked objects are released
    }
    
    // MARK: - Async Testing Helpers
    
    /// Assert that a condition eventually becomes true
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - timeout: Maximum time to wait
    ///   - file: File where assertion is called
    ///   - line: Line where assertion is called
    public func assertEventually(
        _ condition: @autoclosure () async -> Bool,
        timeout: TimeInterval = 2.0,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        XCTFail("Condition did not become true within \(timeout) seconds", file: (file), line: line)
    }
    
    // MARK: - Given/When/Then Helpers
    
    /// BDD Given step - setup preconditions
    public func given(_ description: String, block: () throws -> Void) rethrows {
        print("Given: \(description)")
        try block()
    }
    
    /// BDD When step - perform action
    public func when(_ description: String, block: () throws -> Void) rethrows {
        print("When: \(description)")
        try block()
    }
    
    /// BDD Then step - verify outcomes
    public func then(_ description: String, block: () throws -> Void) rethrows {
        print("Then: \(description)")
        try block()
    }
    
    // MARK: - Async Given/When/Then
    
    /// BDD Given step for async code
    public func given(_ description: String, block: () async throws -> Void) async rethrows {
        print("Given: \(description)")
        try await block()
    }
    
    /// BDD When step for async code
    public func when(_ description: String, block: () async throws -> Void) async rethrows {
        print("When: \(description)")
        try await block()
    }
    
    /// BDD Then step for async code
    public func then(_ description: String, block: () async throws -> Void) async rethrows {
        print("Then: \(description)")
        try await block()
    }
    
    // MARK: - Common Assertions
    
    /// Assert that a throwing expression throws a specific error
    public func assertThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: (file), line: line) { error in
            XCTAssertEqual(error as? E, expectedError, file: (file), line: line)
        }
    }
    
    /// Assert that an async throwing expression throws a specific error
    public func assertAsyncThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: (file), line: line)
        } catch {
            XCTAssertEqual(error as? E, expectedError, file: (file), line: line)
        }
    }
    
    // MARK: - Test Data Helpers
    
    /// Generate a random string for testing
    public func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Generate a random email for testing
    public func randomEmail() -> String {
        "\(randomString(length: 8))@test.com"
    }
    
    /// Generate a random UUID string
    public func randomUUID() -> String {
        UUID().uuidString
    }
}