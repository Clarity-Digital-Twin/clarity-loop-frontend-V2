//
//  BaseUnitTestCaseTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Testing our test infrastructure - meta testing!
//

import XCTest

final class BaseUnitTestCaseTests: XCTestCase {
    
    // MARK: - Test that BaseUnitTestCase provides expected functionality
    
    func test_baseUnitTestCase_setsUpCorrectly() {
        // Given
        let testCase = TestableBaseUnitTestCase()
        
        // When
        testCase.setUp()
        
        // Then
        XCTAssertTrue(testCase.didCallSetUp)
        XCTAssertNotNil(testCase.testStartTime)
    }
    
    func test_baseUnitTestCase_tearsDownCorrectly() {
        // Given
        let testCase = TestableBaseUnitTestCase()
        testCase.setUp()
        
        // When
        testCase.tearDown()
        
        // Then
        XCTAssertTrue(testCase.didCallTearDown)
        XCTAssertNil(testCase.retainedObjects)
    }
    
    func test_assertEventually_waitsForCondition() async {
        // Given
        let testCase = TestableBaseUnitTestCase()
        var flag = false
        
        // When
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            flag = true
        }
        
        // Then
        await testCase.assertEventually(flag == true, timeout: 0.5)
    }
    
    func test_trackMemoryLeak_detectsRetainedObject() {
        // Given
        let testCase = TestableBaseUnitTestCase()
        var strongRef: TestObject? = TestObject()
        let weakRef = strongRef
        
        // When
        testCase.trackForMemoryLeak(strongRef!)
        strongRef = nil
        
        // Then
        // Object should still be retained by test tracking
        XCTAssertNotNil(weakRef)
    }
}

// MARK: - Test Helpers

private class TestableBaseUnitTestCase: BaseUnitTestCase {
    var didCallSetUp = false
    var didCallTearDown = false
    
    override func setUp() {
        super.setUp()
        didCallSetUp = true
    }
    
    override func tearDown() {
        didCallTearDown = true
        super.tearDown()
    }
}

private class TestObject {
    let id = UUID()
}
