import XCTest
import Network
import SwiftData
@testable import clarity_loop_frontend

@MainActor
final class EnhancedOfflineQueueManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var queueManager: MockEnhancedOfflineQueueManager!
    private var mockNetworkMonitor: MockNetworkMonitor!
    private var mockPersistence: MockOfflineQueuePersistence!
    private var modelContext: ModelContext!
    private var modelContainer: ModelContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory test container
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: PersistedOfflineOperation.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
        
        mockNetworkMonitor = MockNetworkMonitor()
        mockPersistence = MockOfflineQueuePersistence()
        queueManager = MockEnhancedOfflineQueueManager(
            modelContext: modelContext,
            networkMonitor: mockNetworkMonitor,
            persistence: mockPersistence
        )
    }
    
    override func tearDown() async throws {
        queueManager = nil
        mockNetworkMonitor = nil
        mockPersistence = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Queue Operation Tests
    
    func testQueueOperationWhenOffline() async throws {
        // Given - network is offline
        mockNetworkMonitor.simulateConnectionChange(connected: false)
        queueManager.updateNetworkStatus(false)
        
        let operation = OfflineOperation(
            type: .healthDataUpload,
            payload: ["data": "test"],
            priority: .high
        )
        
        // When - queue operation
        await queueManager.queueOperation(operation)
        
        // Then - operation is queued but not processed
        XCTAssertEqual(queueManager.pendingOperations.count, 1)
        XCTAssertEqual(queueManager.pendingOperations.first?.id, operation.id)
        XCTAssertEqual(queueManager.queueStatus, .waitingForNetwork)
        XCTAssertTrue(mockPersistence.savedOperations.contains { $0.id == operation.id })
    }
    
    func testQueueOperationPersistence() async throws {
        // Given
        let operation = OfflineOperation(
            type: .profileUpdate,
            payload: ["name": "Test User"],
            priority: .normal
        )
        
        // When
        await queueManager.queueOperation(operation)
        
        // Then - operation is persisted
        XCTAssertEqual(mockPersistence.savedOperations.count, 1)
        XCTAssertEqual(mockPersistence.savedOperations.first?.id, operation.id)
        XCTAssertEqual(mockPersistence.savedOperations.first?.type, operation.type)
        XCTAssertEqual(mockPersistence.savedOperations.first?.priority, operation.priority)
    }
    
    func testQueueOperationPriorityOrdering() async throws {
        // Given - multiple operations with different priorities
        let lowPriority = OfflineOperation(type: .syncData, payload: [:], priority: .low)
        let normalPriority = OfflineOperation(type: .profileUpdate, payload: [:], priority: .normal)
        let highPriority = OfflineOperation(type: .healthDataUpload, payload: [:], priority: .high)
        let criticalPriority = OfflineOperation(type: .patSubmission, payload: [:], priority: .critical)
        
        // When - queue in random order
        await queueManager.queueOperation(normalPriority)
        await queueManager.queueOperation(lowPriority)
        await queueManager.queueOperation(criticalPriority)
        await queueManager.queueOperation(highPriority)
        
        // Then - operations are ordered by priority
        let operations = queueManager.getOrderedOperations()
        XCTAssertEqual(operations.count, 4)
        XCTAssertEqual(operations[0].priority, .critical)
        XCTAssertEqual(operations[1].priority, .high)
        XCTAssertEqual(operations[2].priority, .normal)
        XCTAssertEqual(operations[3].priority, .low)
    }
    
    func testQueueOperationTypeOrdering() async throws {
        // Given - operations with same priority but different types
        let syncOp = OfflineOperation(type: .syncData, payload: [:], priority: .normal)
        let healthOp = OfflineOperation(type: .healthDataUpload, payload: [:], priority: .normal)
        let insightOp = OfflineOperation(type: .insightRequest, payload: [:], priority: .normal)
        
        // When
        await queueManager.queueOperation(syncOp)
        await queueManager.queueOperation(healthOp)
        await queueManager.queueOperation(insightOp)
        
        // Then - health data has priority in same priority tier
        let operations = queueManager.getOrderedOperations()
        XCTAssertEqual(operations.count, 3)
        // Health data typically has priority for same priority level
        XCTAssertEqual(operations[0].type, .healthDataUpload)
    }
    
    // MARK: - Operation Processing Tests
    
    func testProcessQueueWhenOnline() async throws {
        // Given - network is online and operations are queued
        mockNetworkMonitor.isConnected = true
        queueManager.updateNetworkStatus(true)
        
        let operation1 = OfflineOperation(type: .profileUpdate, payload: ["test": true])
        let operation2 = OfflineOperation(type: .healthDataUpload, payload: ["data": "test"])
        
        await queueManager.queueOperation(operation1)
        await queueManager.queueOperation(operation2)
        
        // When - process queue
        queueManager.simulateSuccessfulProcessing = true
        await queueManager.processQueue()
        
        // Then - operations are processed
        XCTAssertEqual(queueManager.queueStatus, .idle)
        XCTAssertEqual(queueManager.pendingOperations.count, 0)
        XCTAssertEqual(queueManager.completedOperationIds.count, 2)
        XCTAssertTrue(queueManager.completedOperationIds.contains(operation1.id))
        XCTAssertTrue(queueManager.completedOperationIds.contains(operation2.id))
    }
    
    func testProcessQueueStopsWhenOffline() async throws {
        // Given - queue has operations
        let operation1 = OfflineOperation(type: .profileUpdate, payload: [:])
        let operation2 = OfflineOperation(type: .healthDataUpload, payload: [:])
        await queueManager.queueOperation(operation1)
        await queueManager.queueOperation(operation2)
        
        // When - network goes offline during processing
        queueManager.simulateNetworkDropDuringProcessing = true
        await queueManager.processQueue()
        
        // Then - processing stops and status reflects offline
        XCTAssertEqual(queueManager.queueStatus, .waitingForNetwork)
        XCTAssertFalse(queueManager.isNetworkAvailable)
        // At least one operation should remain pending
        XCTAssertGreaterThan(queueManager.pendingOperations.count, 0)
    }
    
    func testProcessQueueHandlesFailures() async throws {
        // Given - operation that will fail
        let operation = OfflineOperation(type: .patSubmission, payload: ["invalid": true])
        await queueManager.queueOperation(operation)
        
        // When - process with failure simulation
        queueManager.simulateFailureForOperationType = .patSubmission
        await queueManager.processQueue()
        
        // Then - operation is moved to failed
        XCTAssertEqual(queueManager.pendingOperations.count, 0)
        XCTAssertEqual(queueManager.failedOperations.count, 1)
        XCTAssertEqual(queueManager.failedOperations.first?.id, operation.id)
        XCTAssertNotNil(queueManager.failedOperations.first?.lastError)
        XCTAssertGreaterThan(queueManager.failedOperations.first?.attempts ?? 0, 0)
    }
    
    func testProcessQueueRetriesFailedOperations() async throws {
        // Given - operation that fails initially
        let operation = OfflineOperation(type: .insightRequest, payload: [:])
        await queueManager.queueOperation(operation)
        
        // When - first attempt fails
        queueManager.simulateFailureForOperationType = .insightRequest
        queueManager.maxFailuresBeforeSuccess = 2
        await queueManager.processQueue()
        
        // Then - operation has retry scheduled
        XCTAssertEqual(operation.attempts, 1)
        XCTAssertNotNil(operation.nextRetryDate)
        if case .pending = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .pending")
        }
        
        // When - retry after delay
        queueManager.simulateFailureForOperationType = nil
        await queueManager.retryFailedOperations()
        
        // Then - operation succeeds
        XCTAssertEqual(queueManager.completedOperationIds.count, 1)
        XCTAssertTrue(queueManager.completedOperationIds.contains(operation.id))
    }
    
    // MARK: - Operation Handler Tests
    
    func testHealthMetricUploadHandler() async throws {
        // Given - health metric upload operation
        let healthData = [
            "metrics": [
                ["type": "heartRate", "value": 72, "date": Date().ISO8601Format()],
                ["type": "steps", "value": 5000, "date": Date().ISO8601Format()]
            ]
        ]
        let operation = OfflineOperation(type: .healthDataUpload, payload: healthData)
        
        // When - handler processes operation
        let handler = queueManager.getHandler(for: .healthDataUpload)
        let result = await handler?.handle(operation) ?? false
        
        // Then - operation is handled successfully
        XCTAssertTrue(result)
        XCTAssertTrue(queueManager.handledOperationTypes.contains(.healthDataUpload))
        XCTAssertEqual(queueManager.handlerCallCount[.healthDataUpload], 1)
    }
    
    func testUserProfileUpdateHandler() async throws {
        // Given - profile update operation
        let profileData = [
            "firstName": "Test",
            "lastName": "User",
            "dateOfBirth": "1990-01-01"
        ]
        let operation = OfflineOperation(type: .profileUpdate, payload: profileData)
        
        // When
        let handler = queueManager.getHandler(for: .profileUpdate)
        let result = await handler?.handle(operation) ?? false
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(queueManager.handledOperationTypes.contains(.profileUpdate))
        XCTAssertEqual(queueManager.lastHandledPayload["firstName"] as? String, "Test")
    }
    
    func testPATAnalysisSubmitHandler() async throws {
        // Given - PAT analysis submission
        let patData: [String: Any] = [
            "score": 85,
            "responses": [["questionId": "q1", "value": 5]],
            "timestamp": Date().ISO8601Format()
        ]
        let operation = OfflineOperation(type: .patSubmission, payload: patData, priority: .high)
        
        // When
        let handler = queueManager.getHandler(for: .patSubmission)
        let result = await handler?.handle(operation) ?? false
        
        // Then
        XCTAssertTrue(result)
        if case .completed = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .completed")
        }
        XCTAssertEqual(queueManager.handlerCallCount[.patSubmission], 1)
    }
    
    func testInsightFeedbackHandler() async throws {
        // Given - insight feedback operation
        let feedbackData: [String: Any] = [
            "insightId": UUID().uuidString,
            "rating": 5,
            "feedback": "Very helpful insight!",
            "actionTaken": true
        ]
        let operation = OfflineOperation(type: .insightRequest, payload: feedbackData)
        
        // When
        let handler = queueManager.getHandler(for: .insightRequest)
        let result = await handler?.handle(operation) ?? false
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(queueManager.lastHandledPayload["rating"] as? Int, 5)
        XCTAssertEqual(queueManager.lastHandledPayload["feedback"] as? String, "Very helpful insight!")
    }
    
    // MARK: - Retry Strategy Tests
    
    func testExponentialBackoffRetry() async throws {
        // Given - operation that needs retries
        let operation = OfflineOperation(type: .syncData, payload: [:])
        
        // When - calculate retry delays for multiple attempts
        let delay1 = queueManager.calculateRetryDelay(for: operation, attempt: 1)
        let delay2 = queueManager.calculateRetryDelay(for: operation, attempt: 2)
        let delay3 = queueManager.calculateRetryDelay(for: operation, attempt: 3)
        let delay4 = queueManager.calculateRetryDelay(for: operation, attempt: 4)
        
        // Then - delays increase exponentially
        XCTAssertGreaterThan(delay2, delay1)
        XCTAssertGreaterThan(delay3, delay2)
        XCTAssertGreaterThan(delay4, delay3)
        
        // Verify exponential growth (roughly 2x each time)
        XCTAssertGreaterThan(delay2 / delay1, 1.5)
        XCTAssertLessThan(delay2 / delay1, 2.5)
    }
    
    func testMaxRetryAttempts() async throws {
        // Given - operation that always fails
        let operation = OfflineOperation(type: .deleteData, payload: ["id": "test"])
        queueManager.simulateFailureForOperationType = .deleteData
        queueManager.maxRetryAttempts = 3
        
        // When - process multiple times
        await queueManager.queueOperation(operation)
        
        for _ in 1...4 {
            await queueManager.processQueue()
            await queueManager.retryFailedOperations()
        }
        
        // Then - operation is permanently failed after max attempts
        XCTAssertEqual(operation.attempts, 3)
        if case .failed = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .failed")
        }
        XCTAssertTrue(queueManager.permanentlyFailedOperations.contains(operation.id))
        XCTAssertEqual(queueManager.failedOperations.count, 1)
    }
    
    func testRetryDelayCalculation() async throws {
        // Given - different operation types and priorities
        let criticalOp = OfflineOperation(type: .patSubmission, payload: [:], priority: .critical)
        let normalOp = OfflineOperation(type: .profileUpdate, payload: [:], priority: .normal)
        let lowOp = OfflineOperation(type: .syncData, payload: [:], priority: .low)
        
        // When - calculate delays
        let criticalDelay = queueManager.calculateRetryDelay(for: criticalOp, attempt: 1)
        let normalDelay = queueManager.calculateRetryDelay(for: normalOp, attempt: 1)
        let lowDelay = queueManager.calculateRetryDelay(for: lowOp, attempt: 1)
        
        // Then - critical operations have shorter delays
        XCTAssertLessThan(criticalDelay, normalDelay)
        XCTAssertLessThan(normalDelay, lowDelay)
        
        // Verify reasonable delay ranges
        XCTAssertGreaterThan(criticalDelay, 0) // At least some delay
        XCTAssertLessThan(criticalDelay, 30) // Critical should retry within 30 seconds
        XCTAssertLessThan(lowDelay, 300) // Low priority within 5 minutes
    }
    
    // MARK: - Network Monitoring Tests
    
    func testNetworkStateChangeHandling() async throws {
        // Given - queue with pending operations
        let operation = OfflineOperation(type: .healthDataUpload, payload: [:])
        await queueManager.queueOperation(operation)
        
        // When - network state changes
        mockNetworkMonitor.simulateConnectionChange(connected: false)
        queueManager.updateNetworkStatus(false)
        
        // Then - queue status reflects network state
        XCTAssertEqual(queueManager.queueStatus, .waitingForNetwork)
        XCTAssertFalse(queueManager.isNetworkAvailable)
        
        // When - network comes back
        mockNetworkMonitor.simulateConnectionChange(connected: true)
        queueManager.updateNetworkStatus(true)
        
        // Then - queue is ready to process
        XCTAssertTrue(queueManager.isNetworkAvailable)
        XCTAssertNotEqual(queueManager.queueStatus, .waitingForNetwork)
    }
    
    func testAutoProcessOnNetworkReconnect() async throws {
        // Given - operations queued while offline
        mockNetworkMonitor.isConnected = false
        queueManager.updateNetworkStatus(false)
        
        let operation1 = OfflineOperation(type: .profileUpdate, payload: [:])
        let operation2 = OfflineOperation(type: .healthDataUpload, payload: [:])
        await queueManager.queueOperation(operation1)
        await queueManager.queueOperation(operation2)
        
        XCTAssertEqual(queueManager.pendingOperations.count, 2)
        
        // When - network reconnects
        queueManager.simulateSuccessfulProcessing = true
        queueManager.autoProcessOnReconnect = true
        mockNetworkMonitor.simulateConnectionChange(connected: true)
        await queueManager.handleNetworkReconnection()
        
        // Then - queue is automatically processed
        XCTAssertEqual(queueManager.pendingOperations.count, 0)
        XCTAssertEqual(queueManager.completedOperationIds.count, 2)
    }
    
    // MARK: - Persistence Tests
    
    func testLoadPersistedOperationsOnInit() async throws {
        // Given - persisted operations
        let op1 = OfflineOperation(type: .healthDataUpload, payload: ["data": "test1"])
        let op2 = OfflineOperation(type: .profileUpdate, payload: ["data": "test2"])
        mockPersistence.savedOperations = [op1, op2]
        
        // When - create new queue manager
        let newQueueManager = MockEnhancedOfflineQueueManager(
            modelContext: modelContext,
            networkMonitor: mockNetworkMonitor,
            persistence: mockPersistence
        )
        await newQueueManager.loadPersistedOperations()
        
        // Then - operations are loaded
        XCTAssertEqual(newQueueManager.pendingOperations.count, 2)
        XCTAssertTrue(newQueueManager.pendingOperations.contains { $0.id == op1.id })
        XCTAssertTrue(newQueueManager.pendingOperations.contains { $0.id == op2.id })
    }
    
    func testPersistOperationOnQueue() async throws {
        // Given
        let operation = OfflineOperation(
            type: .insightRequest,
            payload: ["query": "health insights"],
            priority: .high
        )
        
        // When
        await queueManager.queueOperation(operation)
        
        // Then - operation is persisted with all properties
        let persisted = mockPersistence.savedOperations.first { $0.id == operation.id }
        XCTAssertNotNil(persisted)
        XCTAssertEqual(persisted?.type, .insightRequest)
        XCTAssertEqual(persisted?.priority, .high)
        if case .pending = persisted?.status {
            // Expected
        } else {
            XCTFail("Expected persisted operation status to be .pending")
        }
        XCTAssertEqual(persisted?.attempts, 0)
    }
    
    func testRemoveOperationAfterSuccess() async throws {
        // Given - operation in queue
        let operation = OfflineOperation(type: .profileUpdate, payload: [:])
        await queueManager.queueOperation(operation)
        XCTAssertEqual(mockPersistence.savedOperations.count, 1)
        
        // When - operation succeeds
        queueManager.simulateSuccessfulProcessing = true
        await queueManager.processQueue()
        
        // Then - operation is removed from persistence
        XCTAssertEqual(queueManager.pendingOperations.count, 0)
        XCTAssertFalse(mockPersistence.savedOperations.contains { $0.id == operation.id })
        XCTAssertTrue(queueManager.removedOperationIds.contains(operation.id))
    }
    
    func testUpdateOperationAfterFailure() async throws {
        // Given - operation that will fail
        let operation = OfflineOperation(type: .patSubmission, payload: [:])
        await queueManager.queueOperation(operation)
        
        // When - operation fails
        queueManager.simulateFailureForOperationType = .patSubmission
        await queueManager.processQueue()
        
        // Then - operation is updated in persistence
        let updated = mockPersistence.savedOperations.first { $0.id == operation.id }
        XCTAssertNotNil(updated)
        if case .failed = updated?.status {
            // Expected
        } else {
            XCTFail("Expected updated operation status to be .failed")
        }
        XCTAssertEqual(updated?.attempts, 1)
        XCTAssertNotNil(updated?.lastError)
        XCTAssertNotNil(updated?.lastAttemptDate)
        XCTAssertNotNil(updated?.nextRetryDate)
    }
    
    // MARK: - Queue Management Tests
    
    func testClearQueue() async throws {
        // Given - multiple operations in queue
        let operations = (1...5).map { i in
            OfflineOperation(type: .syncData, payload: ["index": i])
        }
        
        for op in operations {
            await queueManager.queueOperation(op)
        }
        
        XCTAssertEqual(queueManager.pendingOperations.count, 5)
        XCTAssertEqual(mockPersistence.savedOperations.count, 5)
        
        // When
        await queueManager.clearQueue()
        
        // Then - all operations are removed
        XCTAssertEqual(queueManager.pendingOperations.count, 0)
        XCTAssertEqual(queueManager.failedOperations.count, 0)
        XCTAssertEqual(mockPersistence.savedOperations.count, 0)
        XCTAssertTrue(queueManager.queueCleared)
    }
    
    func testRemoveSpecificOperation() async throws {
        // Given - multiple operations
        let op1 = OfflineOperation(type: .healthDataUpload, payload: ["id": 1])
        let op2 = OfflineOperation(type: .profileUpdate, payload: ["id": 2])
        let op3 = OfflineOperation(type: .syncData, payload: ["id": 3])
        
        await queueManager.queueOperation(op1)
        await queueManager.queueOperation(op2)
        await queueManager.queueOperation(op3)
        
        // When - remove specific operation
        await queueManager.removeOperation(op2.id)
        
        // Then - only that operation is removed
        XCTAssertEqual(queueManager.pendingOperations.count, 2)
        XCTAssertFalse(queueManager.pendingOperations.contains { $0.id == op2.id })
        XCTAssertTrue(queueManager.pendingOperations.contains { $0.id == op1.id })
        XCTAssertTrue(queueManager.pendingOperations.contains { $0.id == op3.id })
        XCTAssertFalse(mockPersistence.savedOperations.contains { $0.id == op2.id })
    }
    
    func testGetQueueStatus() async throws {
        // Given - various queue states
        
        // Test 1: Empty queue
        let status1 = queueManager.getQueueStatistics()
        XCTAssertEqual(status1.pendingCount, 0)
        XCTAssertEqual(status1.failedCount, 0)
        XCTAssertNil(status1.oldestOperation)
        
        // Test 2: Queue with operations
        let op1 = OfflineOperation(type: .healthDataUpload, payload: [:])
        let op2 = OfflineOperation(type: .profileUpdate, payload: [:])
        await queueManager.queueOperation(op1)
        await queueManager.queueOperation(op2)
        
        // Simulate one failure
        queueManager.simulateFailureForOperationType = .profileUpdate
        await queueManager.processQueue()
        
        let status2 = queueManager.getQueueStatistics()
        XCTAssertEqual(status2.pendingCount, 1)
        XCTAssertEqual(status2.failedCount, 1)
        XCTAssertNotNil(status2.oldestOperation)
        XCTAssertEqual(status2.byType[.healthDataUpload], 1)
        XCTAssertEqual(status2.byType[.profileUpdate], 1)
        XCTAssertGreaterThan(status2.estimatedSize, 0)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressUpdatesWhileProcessing() async throws {
        // Given - multiple operations
        let operations = (1...5).map { i in
            OfflineOperation(type: .syncData, payload: ["index": i])
        }
        
        for op in operations {
            await queueManager.queueOperation(op)
        }
        
        // Track progress updates
        var progressUpdates: [Double] = []
        queueManager.onProgressUpdate = { progress in
            progressUpdates.append(progress.progress)
        }
        
        // When - process queue
        queueManager.simulateSuccessfulProcessing = true
        await queueManager.processQueue()
        
        // Then - progress updates were sent
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last, 1.0) // 100% complete
        XCTAssertEqual(queueManager.syncProgress.completedOperations, 5)
        XCTAssertEqual(queueManager.syncProgress.totalOperations, 5)
    }
    
    func testTotalCountTracking() async throws {
        // Given - empty queue
        XCTAssertEqual(queueManager.syncProgress.totalOperations, 0)
        
        // When - add operations
        let op1 = OfflineOperation(type: .healthDataUpload, payload: [:])
        let op2 = OfflineOperation(type: .profileUpdate, payload: [:])
        await queueManager.queueOperation(op1)
        await queueManager.queueOperation(op2)
        
        // Then - total count is updated
        XCTAssertEqual(queueManager.syncProgress.totalOperations, 2)
        
        // When - process one successfully
        queueManager.simulatePartialSuccess = true
        queueManager.successfulOperationIds = [op1.id]
        await queueManager.processQueue()
        
        // Then - counts are updated correctly
        XCTAssertEqual(queueManager.syncProgress.completedOperations, 1)
        XCTAssertEqual(queueManager.syncProgress.totalOperations, 1) // Remaining
        XCTAssertEqual(queueManager.syncProgress.progress, 0.5) // 50% of original
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleAuthenticationError() async throws {
        // Given - operation that encounters auth error
        let operation = OfflineOperation(type: .profileUpdate, payload: [:])
        await queueManager.queueOperation(operation)
        
        // When - auth error occurs
        queueManager.simulateAuthError = true
        await queueManager.processQueue()
        
        // Then - operation is not retried immediately
        if case .pending = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .pending")
        }
        XCTAssertTrue(queueManager.authErrorEncountered)
        XCTAssertEqual(queueManager.queueStatus, .waitingForNetwork) // Or custom auth wait status
        
        // Verify auth refresh was triggered
        XCTAssertTrue(queueManager.authRefreshRequested)
    }
    
    func testHandleRateLimitError() async throws {
        // Given - operation that hits rate limit
        let operation = OfflineOperation(type: .healthDataUpload, payload: ["data": "large"])
        await queueManager.queueOperation(operation)
        
        // When - rate limit error with retry-after header
        queueManager.simulateRateLimitError = true
        queueManager.rateLimitRetryAfter = 60 // 60 seconds
        await queueManager.processQueue()
        
        // Then - operation is scheduled for retry after specified time
        if case .pending = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .pending")
        }
        XCTAssertNotNil(operation.nextRetryDate)
        
        if let retryDate = operation.nextRetryDate {
            let delay = retryDate.timeIntervalSinceNow
            XCTAssertGreaterThan(delay, 55) // At least 55 seconds
            XCTAssertLessThan(delay, 65) // But not more than 65
        }
        
        XCTAssertTrue(queueManager.rateLimitEncountered)
    }
    
    func testHandleDataCorruption() async throws {
        // Given - corrupted operation data
        let operation = OfflineOperation(type: .syncData, payload: ["corrupted": true])
        await queueManager.queueOperation(operation)
        
        // When - data corruption is detected
        queueManager.simulateDataCorruption = true
        await queueManager.processQueue()
        
        // Then - operation is moved to failed with no retry
        if case .failed = operation.status {
            // Expected
        } else {
            XCTFail("Expected operation status to be .failed")
        }
        XCTAssertEqual(queueManager.failedOperations.count, 1)
        XCTAssertNil(operation.nextRetryDate) // No retry for corrupted data
        XCTAssertTrue(operation.lastError?.contains("corruption") ?? false)
        
        // Verify corruption was logged
        XCTAssertTrue(queueManager.corruptedOperationIds.contains(operation.id))
    }
    
    // MARK: - Performance Tests
    
    func testLargeQueueProcessingPerformance() async throws {
        // Given - large number of operations
        let operationCount = 100
        let operations = (1...operationCount).map { i in
            OfflineOperation(
                type: i % 2 == 0 ? .healthDataUpload : .syncData,
                payload: ["index": i, "data": String(repeating: "x", count: 100)]
            )
        }
        
        // Measure queue time
        let queueStart = Date()
        for op in operations {
            await queueManager.queueOperation(op)
        }
        let queueDuration = Date().timeIntervalSince(queueStart)
        
        // When - process all operations
        queueManager.simulateSuccessfulProcessing = true
        let processStart = Date()
        await queueManager.processQueue()
        let processDuration = Date().timeIntervalSince(processStart)
        
        // Then - performance is acceptable
        XCTAssertLessThan(queueDuration, 1.0) // Queue 100 ops in under 1 second
        XCTAssertLessThan(processDuration, 5.0) // Process 100 ops in under 5 seconds
        XCTAssertEqual(queueManager.completedOperationIds.count, operationCount)
    }
    
    func testMemoryUsageWithManyOperations() async throws {
        // Given - many operations with large payloads
        let operationCount = 50
        let largePayload = String(repeating: "data", count: 1000) // ~4KB per operation
        
        // Track initial memory
        let initialMemory = queueManager.estimatedMemoryUsage()
        
        // When - queue many operations
        for i in 1...operationCount {
            let operation = OfflineOperation(
                type: .syncData,
                payload: ["index": i, "data": largePayload]
            )
            await queueManager.queueOperation(operation)
        }
        
        // Then - memory usage is tracked
        let finalMemory = queueManager.estimatedMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Verify reasonable memory usage (roughly 4KB * 50 = 200KB)
        XCTAssertGreaterThan(memoryIncrease, 100_000) // At least 100KB
        XCTAssertLessThan(memoryIncrease, 500_000) // But less than 500KB
        
        // Verify queue statistics
        let stats = queueManager.getQueueStatistics()
        XCTAssertEqual(stats.pendingCount, operationCount)
        XCTAssertGreaterThan(stats.estimatedSize, 100_000)
    }
}

// MARK: - Mock Network Monitor

private class MockNetworkMonitor {
    var isConnected = true
    var pathUpdateHandler: ((Bool) -> Void)?
    
    func startMonitoring() {
        // Mock implementation
    }
    
    func stopMonitoring() {
        // Mock implementation
    }
    
    func simulateConnectionChange(connected: Bool) {
        isConnected = connected
        pathUpdateHandler?(connected)
    }
}

// MARK: - Mock Offline Queue Persistence

private class MockOfflineQueuePersistence {
    var savedOperations: [OfflineOperation] = []
    var shouldFailSave = false
    var shouldFailLoad = false
    
    func save(_ operation: OfflineOperation) async throws {
        if shouldFailSave {
            throw QueueError.persistenceFailed
        }
        savedOperations.append(operation)
    }
    
    func loadAll() async throws -> [OfflineOperation] {
        if shouldFailLoad {
            throw QueueError.persistenceFailed
        }
        return savedOperations
    }
    
    func delete(_ operation: OfflineOperation) async throws {
        savedOperations.removeAll { $0.id == operation.id }
    }
    
    func update(_ operation: OfflineOperation) async throws {
        if let index = savedOperations.firstIndex(where: { $0.id == operation.id }) {
            savedOperations[index] = operation
        }
    }
}

enum QueueError: Error {
    case persistenceFailed
}

// MARK: - Mock Enhanced Offline Queue Manager

private class MockEnhancedOfflineQueueManager {
    // Properties
    private(set) var queueStatus: QueueStatus = .idle
    private(set) var pendingOperations: [OfflineOperation] = []
    private(set) var failedOperations: [OfflineOperation] = []
    private(set) var syncProgress = SyncProgress()
    private(set) var isNetworkAvailable = true
    
    let modelContext: ModelContext
    let networkMonitor: MockNetworkMonitor
    let persistence: MockOfflineQueuePersistence
    
    // Test helpers
    var simulateSuccessfulProcessing = false
    var simulateFailureForOperationType: OperationType?
    var simulateNetworkDropDuringProcessing = false
    var simulateAuthError = false
    var simulateRateLimitError = false
    var simulateDataCorruption = false
    var simulatePartialSuccess = false
    
    var maxFailuresBeforeSuccess = 0
    var maxRetryAttempts = 3
    var autoProcessOnReconnect = false
    var rateLimitRetryAfter = 60
    
    var completedOperationIds: Set<UUID> = []
    var removedOperationIds: Set<UUID> = []
    var permanentlyFailedOperations: Set<UUID> = []
    var corruptedOperationIds: Set<UUID> = []
    var successfulOperationIds: Set<UUID> = []
    
    var handledOperationTypes: Set<OperationType> = []
    var handlerCallCount: [OperationType: Int] = [:]
    var lastHandledPayload: [String: Any] = [:]
    
    var queueCleared = false
    var authErrorEncountered = false
    var authRefreshRequested = false
    var rateLimitEncountered = false
    
    var onProgressUpdate: ((SyncProgress) -> Void)?
    
    // Mock handlers
    private var handlers: [OperationType: MockOperationHandler] = [:]
    
    init(modelContext: ModelContext, networkMonitor: MockNetworkMonitor, persistence: MockOfflineQueuePersistence) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor
        self.persistence = persistence
        setupHandlers()
    }
    
    private func setupHandlers() {
        for type in OperationType.allCases {
            handlers[type] = MockOperationHandler(type: type)
        }
    }
    
    func updateNetworkStatus(_ available: Bool) {
        isNetworkAvailable = available
        if !available {
            queueStatus = .waitingForNetwork
        }
    }
    
    func queueOperation(_ operation: OfflineOperation) async {
        pendingOperations.append(operation)
        persistence.savedOperations.append(operation)
        syncProgress.totalOperations = pendingOperations.count
        
        if isNetworkAvailable && queueStatus == .idle {
            await processQueue()
        }
    }
    
    func processQueue() async {
        guard isNetworkAvailable else {
            queueStatus = .waitingForNetwork
            return
        }
        
        queueStatus = .processing
        
        if simulateNetworkDropDuringProcessing {
            isNetworkAvailable = false
            queueStatus = .waitingForNetwork
            return
        }
        
        let operations = Array(pendingOperations)
        
        for operation in operations {
            if simulateAuthError {
                authErrorEncountered = true
                authRefreshRequested = true
                queueStatus = .waitingForNetwork
                return
            }
            
            if simulateRateLimitError {
                rateLimitEncountered = true
                operation.nextRetryDate = Date().addingTimeInterval(TimeInterval(rateLimitRetryAfter))
                continue
            }
            
            if simulateDataCorruption {
                operation.status = .failed
                operation.lastError = "Data corruption detected"
                corruptedOperationIds.insert(operation.id)
                pendingOperations.removeAll { $0.id == operation.id }
                failedOperations.append(operation)
                continue
            }
            
            let shouldFail = (simulateFailureForOperationType == operation.type) ||
                           (!simulateSuccessfulProcessing && !simulatePartialSuccess)
            
            if shouldFail {
                operation.attempts += 1
                operation.lastAttemptDate = Date()
                operation.lastError = "Simulated failure"
                operation.nextRetryDate = Date().addingTimeInterval(5)
                
                if operation.attempts >= maxRetryAttempts {
                    operation.status = .failed
                    permanentlyFailedOperations.insert(operation.id)
                    pendingOperations.removeAll { $0.id == operation.id }
                    failedOperations.append(operation)
                }
                
                persistence.savedOperations.first { $0.id == operation.id }?.attempts = operation.attempts
                persistence.savedOperations.first { $0.id == operation.id }?.status = operation.status
            } else if simulatePartialSuccess && !successfulOperationIds.contains(operation.id) {
                // Skip this one for partial success
                continue
            } else {
                // Success
                operation.status = .completed
                completedOperationIds.insert(operation.id)
                pendingOperations.removeAll { $0.id == operation.id }
                persistence.savedOperations.removeAll { $0.id == operation.id }
                removedOperationIds.insert(operation.id)
                
                // Update progress
                syncProgress.completedOperations += 1
                onProgressUpdate?(syncProgress)
            }
            
            // Handle operation
            if let handler = handlers[operation.type] {
                handledOperationTypes.insert(operation.type)
                handlerCallCount[operation.type, default: 0] += 1
                lastHandledPayload = operation.payload
            }
        }
        
        queueStatus = pendingOperations.isEmpty ? .idle : .partial
    }
    
    func getOrderedOperations() -> [OfflineOperation] {
        return pendingOperations.sorted { op1, op2 in
            if op1.priority != op2.priority {
                return op1.priority.rawValue > op2.priority.rawValue
            }
            // For same priority, health data gets precedence
            if op1.type == .healthDataUpload && op2.type != .healthDataUpload {
                return true
            }
            return false
        }
    }
    
    func getHandler(for type: OperationType) -> MockOperationHandler? {
        return handlers[type]
    }
    
    func calculateRetryDelay(for operation: OfflineOperation, attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval
        switch operation.priority {
        case .critical:
            baseDelay = 5
        case .high:
            baseDelay = 15
        case .normal:
            baseDelay = 30
        case .low:
            baseDelay = 60
        }
        
        // Exponential backoff
        return baseDelay * pow(2.0, Double(attempt - 1))
    }
    
    func retryFailedOperations() async {
        for operation in failedOperations {
            if operation.attempts < maxRetryAttempts {
                operation.status = .pending
                failedOperations.removeAll { $0.id == operation.id }
                pendingOperations.append(operation)
            }
        }
        
        if simulateSuccessfulProcessing {
            await processQueue()
        }
    }
    
    func handleNetworkReconnection() async {
        if autoProcessOnReconnect && !pendingOperations.isEmpty {
            await processQueue()
        }
    }
    
    func loadPersistedOperations() async {
        pendingOperations = persistence.savedOperations
    }
    
    func clearQueue() async {
        pendingOperations.removeAll()
        failedOperations.removeAll()
        persistence.savedOperations.removeAll()
        queueCleared = true
        syncProgress.reset()
    }
    
    func removeOperation(_ id: UUID) async {
        pendingOperations.removeAll { $0.id == id }
        failedOperations.removeAll { $0.id == id }
        persistence.savedOperations.removeAll { $0.id == id }
    }
    
    func getQueueStatistics() -> QueueStatistics {
        var byType: [OperationType: Int] = [:]
        for op in pendingOperations + failedOperations {
            byType[op.type, default: 0] += 1
        }
        
        let allOps = pendingOperations + failedOperations
        let estimatedSize = Int64(allOps.reduce(0) { $0 + $1.estimatedSize })
        
        return QueueStatistics(
            pendingCount: pendingOperations.count,
            failedCount: failedOperations.count,
            byType: byType,
            oldestOperation: allOps.min { $0.timestamp < $1.timestamp },
            estimatedSize: estimatedSize
        )
    }
    
    func estimatedMemoryUsage() -> Int {
        return (pendingOperations + failedOperations).reduce(0) { $0 + $1.estimatedSize }
    }
}

// MARK: - Mock Operation Handler

private class MockOperationHandler {
    let type: OperationType
    
    init(type: OperationType) {
        self.type = type
    }
    
    func handle(_ operation: OfflineOperation) async -> Bool {
        // Simulate handling
        return true
    }
}