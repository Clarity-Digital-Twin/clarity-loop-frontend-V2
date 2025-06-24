import XCTest
import SwiftData
@testable import clarity_loop_frontend

@MainActor
final class BaseViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewModel: TestableBaseViewModel!
    private var modelContext: ModelContext!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test ModelContext
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: TestEntity.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
        viewModel = TestableBaseViewModel(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Loading State Tests
    
    func testIsLoadingInitiallyFalse() async throws {
        // Assert
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false initially")
    }
    
    func testPerformOperationSetsLoadingState() async throws {
        // Arrange
        var loadingStates: [Bool] = []
        
        // Act
        await viewModel.performOperation {
            loadingStates.append(self.viewModel.isLoading)
            // Simulate some async work
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            loadingStates.append(self.viewModel.isLoading)
        }
        
        // Assert
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after operation")
        XCTAssertEqual(loadingStates, [true, true], "isLoading should be true during operation")
    }
    
    // MARK: - Error Handling Tests
    
    func testPerformOperationHandlesError() async throws {
        // Arrange
        let expectedError = TestError.testCase
        viewModel.errorToThrow = expectedError
        
        // Act
        await viewModel.performOperation {
            try await self.viewModel.testOperation()
        }
        
        // Assert
        XCTAssertNotNil(viewModel.currentError, "Error should be set")
        XCTAssertEqual(viewModel.currentError?.localizedDescription, expectedError.localizedDescription)
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after error")
    }
    
    func testErrorIsSetOnFailure() async throws {
        // Arrange
        let customError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        // Act
        await viewModel.performOperation {
            throw customError
        }
        
        // Assert
        XCTAssertNotNil(viewModel.currentError, "Error should be captured")
        if let nsError = viewModel.currentError as NSError? {
            XCTAssertEqual(nsError.domain, "TestDomain")
            XCTAssertEqual(nsError.code, 123)
            XCTAssertEqual(nsError.localizedDescription, "Test error message")
        } else {
            XCTFail("Expected NSError")
        }
    }
    
    // MARK: - SwiftData Operation Tests
    
    func testCreateEntitySucceeds() async throws {
        // Arrange
        let entity = TestEntity(name: "Test Entity")
        
        // Act
        await viewModel.performOperation {
            self.modelContext.insert(entity)
            try self.modelContext.save()
        }
        
        // Assert
        XCTAssertNil(viewModel.currentError, "Should not have error")
        
        // Verify entity was saved
        let descriptor = FetchDescriptor<TestEntity>()
        let entities = try modelContext.fetch(descriptor)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.name, "Test Entity")
    }
    
    func testUpdateEntitySucceeds() async throws {
        // Arrange
        let entity = TestEntity(name: "Original Name")
        modelContext.insert(entity)
        try modelContext.save()
        
        // Act
        await viewModel.performOperation {
            entity.name = "Updated Name"
            try self.modelContext.save()
        }
        
        // Assert
        XCTAssertNil(viewModel.currentError, "Should not have error")
        
        // Verify entity was updated
        let descriptor = FetchDescriptor<TestEntity>()
        let entities = try modelContext.fetch(descriptor)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.name, "Updated Name")
    }
    
    func testDeleteEntitySucceeds() async throws {
        // Arrange
        let entity = TestEntity(name: "To Delete")
        modelContext.insert(entity)
        try modelContext.save()
        
        // Act
        await viewModel.performOperation {
            self.modelContext.delete(entity)
            try self.modelContext.save()
        }
        
        // Assert
        XCTAssertNil(viewModel.currentError, "Should not have error")
        
        // Verify entity was deleted
        let descriptor = FetchDescriptor<TestEntity>()
        let entities = try modelContext.fetch(descriptor)
        XCTAssertEqual(entities.count, 0, "Entity should be deleted")
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryWithBackoffSucceeds() async throws {
        // Arrange
        viewModel.failureCount = 2 // Fail first 2 times
        var attemptCount = 0
        
        // Act
        let result = await viewModel.retryWithBackoff(maxAttempts: 3) {
            attemptCount += 1
            if attemptCount <= self.viewModel.failureCount {
                throw TestError.temporaryFailure
            }
            return "Success"
        }
        
        // Assert
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 3, "Should have tried 3 times")
        XCTAssertEqual(viewModel.retryAttempts.count, 3, "Should track all attempts")
    }
    
    func testRetryWithBackoffRespectsMaxAttempts() async throws {
        // Arrange
        viewModel.failureCount = 5 // Always fail
        var attemptCount = 0
        
        // Act
        let result = await viewModel.retryWithBackoff(maxAttempts: 3, baseDelay: 0.01) {
            attemptCount += 1
            throw TestError.temporaryFailure
        }
        
        // Assert
        XCTAssertNil(result, "Should return nil after max attempts")
        XCTAssertEqual(attemptCount, 3, "Should stop after max attempts")
        XCTAssertEqual(viewModel.retryAttempts.count, 3, "Should track all attempts")
        
        // Verify exponential backoff delays were used
        if viewModel.retryAttempts.count >= 2 {
            let delay1 = viewModel.retryAttempts[0].1
            let delay2 = viewModel.retryAttempts[1].1
            XCTAssertTrue(delay2 > delay1, "Delays should increase exponentially")
        }
    }
    
    // MARK: - Batch Operation Tests
    
    func testPerformBatchOperationSucceeds() async throws {
        // Arrange
        let items = ["A", "B", "C", "D", "E"]
        var processedItems: [String] = []
        
        // Act
        await viewModel.performBatchOperation(
            items: items,
            batchSize: 2
        ) { batch in
            processedItems.append(contentsOf: batch)
            // Simulate processing time
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Assert
        XCTAssertEqual(processedItems.sorted(), items.sorted(), "All items should be processed")
        XCTAssertNil(viewModel.currentError, "Should not have error")
        
        // Verify batching
        XCTAssertEqual(viewModel.batchesProcessed, 3, "Should process 3 batches (2+2+1)")
    }
    
    func testPerformBatchOperationReportsProgress() async throws {
        // Arrange
        let items = Array(1...10)
        var progressReports: [Double] = []
        
        // Act
        await viewModel.performBatchOperation(
            items: items,
            batchSize: 3,
            progress: { current, total in
                let percentage = Double(current) / Double(total)
                progressReports.append(percentage)
            }
        ) { batch in
            // Process batch
            try await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds
        }
        
        // Assert
        XCTAssertGreaterThan(progressReports.count, 0, "Should report progress")
        XCTAssertEqual(progressReports.last, 1.0, accuracy: 0.01, "Final progress should be 100%")
        
        // Verify progress increases monotonically
        for i in 1..<progressReports.count {
            XCTAssertGreaterThanOrEqual(progressReports[i], progressReports[i-1], "Progress should not decrease")
        }
    }
}

// MARK: - Test Helpers

@MainActor
private class TestableBaseViewModel: BaseViewModel {
    var operationCalled = false
    var errorToThrow: Error?
    var failureCount = 0
    var retryAttempts: [(Int, TimeInterval)] = []
    var batchesProcessed = 0
    
    func testOperation() async throws {
        operationCalled = true
        if let error = errorToThrow {
            throw error
        }
    }
    
    func retryWithBackoff<T>(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async -> T? {
        for attempt in 1...maxAttempts {
            do {
                retryAttempts.append((attempt, baseDelay * pow(2, Double(attempt - 1))))
                return try await operation()
            } catch {
                if attempt == maxAttempts {
                    return nil
                }
                // Exponential backoff
                let delay = baseDelay * pow(2, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        return nil
    }
    
    func performBatchOperation<T>(
        items: [T],
        batchSize: Int,
        progress: ((Int, Int) -> Void)? = nil,
        operation: @escaping ([T]) async throws -> Void
    ) async {
        await performOperation {
            var processed = 0
            for index in stride(from: 0, to: items.count, by: batchSize) {
                let endIndex = min(index + batchSize, items.count)
                let batch = Array(items[index..<endIndex])
                
                try await operation(batch)
                self.batchesProcessed += 1
                
                processed += batch.count
                progress?(processed, items.count)
            }
        }
    }
}

// Test entity for SwiftData operations
@Model
private class TestEntity {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

// Test errors
private enum TestError: LocalizedError {
    case testCase
    case temporaryFailure
    
    var errorDescription: String? {
        switch self {
        case .testCase:
            return "Test error occurred"
        case .temporaryFailure:
            return "Temporary failure for retry testing"
        }
    }
}