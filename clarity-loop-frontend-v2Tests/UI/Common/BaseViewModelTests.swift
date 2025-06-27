//
//  BaseViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for BaseViewModel following TDD principles
//

import XCTest
@testable import ClarityUI
import Observation

final class BaseViewModelTests: XCTestCase {
    
    // MARK: - Test ViewModel
    
    // Don't use @Observable in test classes - it causes compilation issues
    final class TestViewModel: BaseViewModel<String> {
        var loadDataCalled = false
        var mockData: String?
        var mockError: Error?
        var mockDelay: TimeInterval = 0
        
        @MainActor
        override func loadData() async throws -> String? {
            loadDataCalled = true
            
            if mockDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
            
            if let error = mockError {
                throw error
            }
            
            return mockData
        }
    }
    
    // MARK: - Tests
    
    @MainActor
    func test_initialState_shouldBeIdle() {
        // Given/When
        let sut = TestViewModel()
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isSuccess)
        XCTAssertFalse(sut.isError)
        XCTAssertFalse(sut.isEmpty)
    }
    
    @MainActor
    func test_load_shouldSetLoadingState() async {
        // Given
        let sut = TestViewModel()
        sut.mockDelay = 0.1 // Add delay to observe loading state
        sut.mockData = "Test Data"
        
        // When
        let task = Task { await sut.load() }
        
        // Then - Check loading state immediately
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertEqual(sut.viewState, .loading)
        XCTAssertTrue(sut.isLoading)
        XCTAssertTrue(sut.loadDataCalled)
        
        // Cleanup
        await task.value
    }
    
    @MainActor
    func test_load_withData_shouldSetSuccessState() async {
        // Given
        let sut = TestViewModel()
        sut.mockData = "Test Data"
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.viewState, .success("Test Data"))
        XCTAssertTrue(sut.isSuccess)
        XCTAssertEqual(sut.value, "Test Data")
    }
    
    @MainActor
    func test_load_withNilData_shouldSetEmptyState() async {
        // Given
        let sut = TestViewModel()
        sut.mockData = nil
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.viewState, .empty)
        XCTAssertTrue(sut.isEmpty)
        XCTAssertNil(sut.value)
    }
    
    @MainActor
    func test_load_withError_shouldSetErrorState() async {
        // Given
        let sut = TestViewModel()
        let expectedError = TestError.testError
        sut.mockError = expectedError
        
        // When
        await sut.load()
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertEqual(error as? TestError, expectedError)
        } else {
            XCTFail("Expected error state")
        }
        XCTAssertTrue(sut.isError)
        XCTAssertNotNil(sut.error)
    }
    
    @MainActor
    func test_reload_shouldResetAndLoadAgain() async {
        // Given
        let sut = TestViewModel()
        sut.mockData = "Initial Data"
        await sut.load()
        XCTAssertEqual(sut.viewState, .success("Initial Data"))
        
        // When
        sut.mockData = "Updated Data"
        sut.loadDataCalled = false
        await sut.reload()
        
        // Then
        XCTAssertTrue(sut.loadDataCalled)
        XCTAssertEqual(sut.viewState, .success("Updated Data"))
    }
    
    @MainActor
    func test_handleError_shouldSetErrorState() {
        // Given
        let sut = TestViewModel()
        let expectedError = TestError.testError
        
        // When
        sut.handleError(expectedError)
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertEqual(error as? TestError, expectedError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    @MainActor
    func test_setSuccess_shouldUpdateState() {
        // Given
        let sut = TestViewModel()
        
        // When
        sut.setSuccess("Test Data")
        
        // Then
        XCTAssertEqual(sut.viewState, .success("Test Data"))
    }
    
    @MainActor
    func test_setEmpty_shouldUpdateState() {
        // Given
        let sut = TestViewModel()
        
        // When
        sut.setEmpty()
        
        // Then
        XCTAssertEqual(sut.viewState, .empty)
    }
    
    @MainActor
    func test_reset_shouldSetIdleState() async {
        // Given
        let sut = TestViewModel()
        sut.mockData = "Test Data"
        await sut.load()
        XCTAssertEqual(sut.viewState, .success("Test Data"))
        
        // When
        sut.reset()
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
    }
}

// MARK: - Test Error

private enum TestError: Error, Equatable {
    case testError
}