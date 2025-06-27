//
//  ViewStateTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for ViewState Pattern
//

import XCTest
@testable import ClarityUI

final class ViewStateTests: XCTestCase {
    
    // MARK: - Test Data
    
    struct TestData: Equatable {
        let value: String
    }
    
    struct TestError: Error, Equatable {
        let message: String
    }
    
    // MARK: - Enum Cases Tests
    
    func test_viewState_shouldHaveIdleCase() {
        // When
        let state = ViewState<TestData>.idle
        
        // Then
        if case .idle = state {
            // Success
        } else {
            XCTFail("ViewState should have idle case")
        }
    }
    
    func test_viewState_shouldHaveLoadingCase() {
        // When
        let state = ViewState<TestData>.loading
        
        // Then
        if case .loading = state {
            // Success
        } else {
            XCTFail("ViewState should have loading case")
        }
    }
    
    func test_viewState_shouldHaveSuccessCase() {
        // Given
        let data = TestData(value: "test")
        
        // When
        let state = ViewState<TestData>.success(data)
        
        // Then
        if case .success(let result) = state {
            XCTAssertEqual(result, data)
        } else {
            XCTFail("ViewState should have success case with associated value")
        }
    }
    
    func test_viewState_shouldHaveErrorCase() {
        // Given
        let error = TestError(message: "test error")
        
        // When
        let state = ViewState<TestData>.error(error)
        
        // Then
        if case .error(let result) = state {
            XCTAssertEqual(result as? TestError, error)
        } else {
            XCTFail("ViewState should have error case with associated error")
        }
    }
    
    func test_viewState_shouldHaveEmptyCase() {
        // When
        let state = ViewState<TestData>.empty
        
        // Then
        if case .empty = state {
            // Success
        } else {
            XCTFail("ViewState should have empty case")
        }
    }
    
    // MARK: - Helper Properties Tests
    
    func test_isIdle_shouldReturnTrueForIdleState() {
        // Given
        let state = ViewState<TestData>.idle
        
        // Then
        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertFalse(state.isEmpty)
    }
    
    func test_isLoading_shouldReturnTrueForLoadingState() {
        // Given
        let state = ViewState<TestData>.loading
        
        // Then
        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertFalse(state.isEmpty)
    }
    
    func test_isSuccess_shouldReturnTrueForSuccessState() {
        // Given
        let state = ViewState<TestData>.success(TestData(value: "test"))
        
        // Then
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertFalse(state.isEmpty)
    }
    
    func test_isError_shouldReturnTrueForErrorState() {
        // Given
        let state = ViewState<TestData>.error(TestError(message: "error"))
        
        // Then
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertTrue(state.isError)
        XCTAssertFalse(state.isEmpty)
    }
    
    func test_isEmpty_shouldReturnTrueForEmptyState() {
        // Given
        let state = ViewState<TestData>.empty
        
        // Then
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertTrue(state.isEmpty)
    }
    
    // MARK: - Value Extraction Tests
    
    func test_value_shouldReturnDataForSuccessState() {
        // Given
        let data = TestData(value: "test data")
        let state = ViewState<TestData>.success(data)
        
        // Then
        XCTAssertEqual(state.value, data)
    }
    
    func test_value_shouldReturnNilForNonSuccessStates() {
        // Given
        let states: [ViewState<TestData>] = [
            .idle,
            .loading,
            .error(TestError(message: "error")),
            .empty
        ]
        
        // Then
        for state in states {
            XCTAssertNil(state.value)
        }
    }
    
    func test_error_shouldReturnErrorForErrorState() {
        // Given
        let error = TestError(message: "test error")
        let state = ViewState<TestData>.error(error)
        
        // Then
        XCTAssertNotNil(state.error)
        XCTAssertEqual(state.error as? TestError, error)
    }
    
    func test_error_shouldReturnNilForNonErrorStates() {
        // Given
        let states: [ViewState<TestData>] = [
            .idle,
            .loading,
            .success(TestData(value: "data")),
            .empty
        ]
        
        // Then
        for state in states {
            XCTAssertNil(state.error)
        }
    }
    
    // MARK: - Equatable Tests
    
    func test_viewState_shouldBeEquatable() {
        // Given
        let data = TestData(value: "test")
        let error = TestError(message: "error")
        
        // Then
        XCTAssertEqual(ViewState<TestData>.idle, ViewState<TestData>.idle)
        XCTAssertEqual(ViewState<TestData>.loading, ViewState<TestData>.loading)
        XCTAssertEqual(ViewState<TestData>.success(data), ViewState<TestData>.success(data))
        XCTAssertEqual(ViewState<TestData>.empty, ViewState<TestData>.empty)
        
        XCTAssertNotEqual(ViewState<TestData>.idle, ViewState<TestData>.loading)
        XCTAssertNotEqual(ViewState<TestData>.success(data), ViewState<TestData>.empty)
    }
    
    // MARK: - Convenience Methods Tests
    
    func test_mapValue_shouldTransformSuccessValue() {
        // Given
        let state = ViewState<Int>.success(42)
        
        // When
        let mapped: ViewState<String> = state.map { String($0) }
        
        // Then
        XCTAssertEqual(mapped.value, "42")
    }
    
    func test_mapValue_shouldPreserveOtherStates() {
        // Given
        let error = TestError(message: "error")
        let states: [(ViewState<Int>, ViewState<String>)] = [
            (.idle, .idle),
            (.loading, .loading),
            (.error(error), .error(error)),
            (.empty, .empty)
        ]
        
        // Then
        for (input, expected) in states {
            let mapped: ViewState<String> = input.map { String($0) }
            
            switch (mapped, expected) {
            case (.idle, .idle), (.loading, .loading), (.empty, .empty):
                // Good
                break
            case (.error(let e1), .error(let e2)):
                XCTAssertEqual(e1 as? TestError, e2 as? TestError)
            default:
                XCTFail("Map should preserve state type")
            }
        }
    }
    
    // MARK: - Usage in ViewModel Tests
    
    func test_viewState_shouldWorkWithObservableViewModel() {
        // Given
        @Observable
        final class TestViewModel {
            private(set) var state: ViewState<[TestData]> = .idle
            
            func loadData() {
                state = .loading
                // Simulate async work
                state = .success([TestData(value: "item1"), TestData(value: "item2")])
            }
            
            func loadEmpty() {
                state = .loading
                state = .empty
            }
            
            func loadWithError() {
                state = .loading
                state = .error(TestError(message: "Network error"))
            }
        }
        
        // When
        let viewModel = TestViewModel()
        
        // Then - Initial state
        XCTAssertTrue(viewModel.state.isIdle)
        
        // Load data
        viewModel.loadData()
        XCTAssertTrue(viewModel.state.isSuccess)
        XCTAssertEqual(viewModel.state.value?.count, 2)
        
        // Load empty
        viewModel.loadEmpty()
        XCTAssertTrue(viewModel.state.isEmpty)
        
        // Load with error
        viewModel.loadWithError()
        XCTAssertTrue(viewModel.state.isError)
        XCTAssertNotNil(viewModel.state.error)
    }
}