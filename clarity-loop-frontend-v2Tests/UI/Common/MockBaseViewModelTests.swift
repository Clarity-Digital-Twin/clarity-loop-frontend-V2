//
//  MockBaseViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for MockBaseViewModel to ensure it works correctly for testing
//

import XCTest
@testable import ClarityUI

final class MockBaseViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: MockBaseViewModel<String>!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        sut = MockBaseViewModel<String>()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    @MainActor
    func test_initialState_shouldBeIdle() {
        // Given/When - initial state
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertEqual(sut.loadCallCount, 0)
        XCTAssertEqual(sut.reloadCallCount, 0)
        XCTAssertEqual(sut.handleErrorCallCount, 0)
    }
    
    @MainActor
    func test_simulateLoading_shouldSetLoadingState() {
        // When
        sut.simulateLoading()
        
        // Then
        XCTAssertEqual(sut.viewState, .loading)
        XCTAssertTrue(sut.isLoading)
    }
    
    @MainActor
    func test_simulateSuccess_shouldSetSuccessState() {
        // Given
        let testData = "Test Success Data"
        
        // When
        sut.simulateSuccess(testData)
        
        // Then
        XCTAssertEqual(sut.viewState, .success(testData))
        XCTAssertTrue(sut.isSuccess)
        XCTAssertEqual(sut.value, testData)
    }
    
    @MainActor
    func test_simulateError_shouldSetErrorState() {
        // Given
        let testError = MockViewModelError.testError
        
        // When
        sut.simulateError(testError)
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertEqual(error as? MockViewModelError, testError)
        } else {
            XCTFail("Expected error state")
        }
        XCTAssertTrue(sut.isError)
    }
    
    @MainActor
    func test_simulateEmpty_shouldSetEmptyState() {
        // When
        sut.simulateEmpty()
        
        // Then
        XCTAssertEqual(sut.viewState, .empty)
        XCTAssertTrue(sut.isEmpty)
    }
    
    @MainActor
    func test_load_withMockData_shouldReturnSuccess() async {
        // Given
        sut.mockData = "Mock Data"
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.loadCallCount, 1)
        XCTAssertEqual(sut.viewState, .success("Mock Data"))
    }
    
    @MainActor
    func test_load_withMockError_shouldReturnError() async {
        // Given
        sut.mockError = MockViewModelError.networkError
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.loadCallCount, 1)
        if case .error(let error) = sut.viewState {
            XCTAssertEqual(error as? MockViewModelError, .networkError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    @MainActor
    func test_load_withShouldReturnNil_shouldSetEmpty() async {
        // Given
        sut.shouldReturnNil = true
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.loadCallCount, 1)
        XCTAssertEqual(sut.viewState, .empty)
    }
    
    @MainActor
    func test_reload_shouldIncrementCounter() async {
        // Given
        sut.mockData = "Test Data"
        
        // When
        await sut.reload()
        
        // Then
        XCTAssertEqual(sut.reloadCallCount, 1)
        XCTAssertEqual(sut.loadCallCount, 1) // reload calls load
    }
    
    @MainActor
    func test_handleError_shouldTrackError() {
        // Given
        let testError = MockViewModelError.validationError("Invalid input")
        
        // When
        sut.handleError(testError)
        
        // Then
        XCTAssertEqual(sut.handleErrorCallCount, 1)
        XCTAssertNotNil(sut.lastHandledError)
        if case .error(let error) = sut.viewState {
            XCTAssertEqual(error as? MockViewModelError, testError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    @MainActor
    func test_resetMock_shouldResetAllState() async {
        // Given - setup some state
        sut.mockData = "Test Data"
        sut.mockError = MockViewModelError.testError
        sut.mockDelay = 1.0
        sut.shouldReturnNil = true
        await sut.load()
        sut.handleError(MockViewModelError.networkError)
        
        // When
        sut.resetMock()
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertEqual(sut.loadCallCount, 0)
        XCTAssertEqual(sut.reloadCallCount, 0)
        XCTAssertEqual(sut.handleErrorCallCount, 0)
        XCTAssertNil(sut.lastHandledError)
        XCTAssertNil(sut.mockData)
        XCTAssertNil(sut.mockError)
        XCTAssertEqual(sut.mockDelay, 0)
        XCTAssertFalse(sut.shouldReturnNil)
    }
    
    @MainActor
    func test_mockDelay_shouldDelayExecution() async {
        // Given
        sut.mockData = "Delayed Data"
        sut.mockDelay = 0.1 // 100ms delay
        
        // When
        let startTime = Date()
        await sut.load()
        let endTime = Date()
        
        // Then
        let elapsed = endTime.timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
        XCTAssertEqual(sut.viewState, .success("Delayed Data"))
    }
}
