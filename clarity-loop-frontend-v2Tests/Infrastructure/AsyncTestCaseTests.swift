//
//  AsyncTestCaseTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for AsyncTestCase functionality
//

import XCTest
@testable import ClarityCore

final class AsyncTestCaseTests: XCTestCase {
    
    // MARK: - Test AsyncTestCase Functionality
    
    func test_asyncTestCase_providesAsyncAssertions() async throws {
        // Given
        class TestCase: AsyncTestCase {}
        let testCase = TestCase()
        
        // When - using async assertion helper
        await testCase.assertAsync {
            // Async operation
            try await Task.sleep(nanoseconds: 100_000) // 0.1ms
            return true
        }
        
        // Then - assertion completes without error
    }
    
    func test_asyncTestCase_handlesAsyncTimeouts() async throws {
        // Given
        class TestCase: AsyncTestCase {}
        let testCase = TestCase()
        
        // When/Then - should handle timeout gracefully
        await testCase.assertAsyncThrows(timeout: 0.1) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    func test_asyncTestCase_providesExpectationWrappers() async throws {
        // Given
        class TestCase: AsyncTestCase {}
        let testCase = TestCase()
        
        // When
        let result = await testCase.waitForAsync(timeout: 1.0) { completion in
            Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                completion(42)
            }
        }
        
        // Then
        XCTAssertEqual(result, 42)
    }
    
    func test_asyncTestCase_providesObservableHelpers() async throws {
        // Given
        @Observable
        class TestViewModel {
            var value: Int = 0
            
            func updateValue() async {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                value = 42
            }
        }
        
        class TestCase: AsyncTestCase {}
        let testCase = TestCase()
        let viewModel = TestViewModel()
        
        // When
        Task { await viewModel.updateValue() }
        
        // Then
        await testCase.waitForObservableChange(
            on: viewModel,
            keyPath: \.value,
            expectedValue: 42,
            timeout: 1.0
        )
    }
    
    func test_asyncTestCase_providesAsyncSetupTeardown() async throws {
        // Given
        class TestCase: AsyncTestCase {
            var setupCalled = false
            var teardownCalled = false
            
            override func asyncSetUp() async throws {
                try await super.asyncSetUp()
                setupCalled = true
            }
            
            override func asyncTearDown() async throws {
                teardownCalled = true
                try await super.asyncTearDown()
            }
        }
        
        let testCase = TestCase()
        
        // When
        try await testCase.asyncSetUp()
        try await testCase.asyncTearDown()
        
        // Then
        XCTAssertTrue(testCase.setupCalled)
        XCTAssertTrue(testCase.teardownCalled)
    }
    
    func test_asyncTestCase_canTestAsyncErrorThrowing() async throws {
        // Given
        enum TestError: Error {
            case expected
        }
        
        class TestCase: AsyncTestCase {}
        let testCase = TestCase()
        
        // When/Then
        await testCase.assertAsyncThrows(error: TestError.expected) {
            throw TestError.expected
        }
    }
}