import XCTest
@testable import clarity_loop_frontend

final class HealthDataSyncManagerTests: XCTestCase {
    
    private var sut: HealthDataSyncManager!
    private var mockHealthKitService: MockHealthKitService!
    private var mockAuthService: MockAuthService!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        mockHealthKitService = MockHealthKitService()
        mockAuthService = MockAuthService()
        sut = HealthDataSyncManager(
            healthKitService: mockHealthKitService,
            authService: mockAuthService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockHealthKitService = nil
        mockAuthService = nil
        super.tearDown()
    }
    
    @MainActor
    func testIncrementalSync() async throws {
        // Given
        let userId = "test-user-123"
        mockAuthService.mockCurrentUser = AuthUser(
            id: userId,
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Mock data would be configured here if needed
        
        // Configure mock to succeed
        mockHealthKitService.shouldSucceed = true
        
        // When - First sync
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertEqual(sut.syncProgress, 1.0)
        
        let firstSyncDate = sut.lastSyncDate!
        
        // When - Second sync (incremental)
        // Mock continues to succeed
        mockHealthKitService.shouldSucceed = true
        
        await sut.syncHealthData()
        
        // Then - Verify incremental sync
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertGreaterThan(sut.lastSyncDate!, firstSyncDate)
        
        // Could verify mock was called with correct date range if tracking calls
    }
    
    @MainActor
    func testSyncWithNoNewData() async throws {
        // Given
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Configure mock to succeed with no data
        mockHealthKitService.shouldSucceed = true
        
        // When
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertEqual(sut.syncProgress, 1.0)
    }
    
    @MainActor
    func testSyncFailure() async throws {
        // Given
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Configure mock to fail
        mockHealthKitService.shouldSucceed = false
        
        // When
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNotNil(sut.syncError)
        XCTAssertNil(sut.lastSyncDate)
    }
}

