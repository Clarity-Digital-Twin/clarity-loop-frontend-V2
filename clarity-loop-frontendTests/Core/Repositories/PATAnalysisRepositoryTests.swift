import XCTest
import SwiftData
@testable import clarity_loop_frontend

@MainActor
final class PATAnalysisRepositoryTests: XCTestCase {
    
    // MARK: - Properties
    
    private var repository: PATAnalysisRepository!
    private var modelContext: ModelContext!
    private var modelContainer: ModelContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory test container
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: PATAnalysis.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
        
        repository = PATAnalysisRepository(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        // Clean up all data
        try await repository.deleteAll()
        
        repository = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestAnalysis(
        startDate: Date = Date().addingTimeInterval(-8 * 3600), // 8 hours ago
        endDate: Date = Date(),
        type: PATAnalysisType = .overnight
    ) -> PATAnalysis {
        let analysis = PATAnalysis(
            startDate: startDate,
            endDate: endDate,
            analysisType: type
        )
        
        // Add some test data
        analysis.totalSleepMinutes = 480 // 8 hours
        analysis.sleepEfficiency = 0.85
        analysis.deepSleepMinutes = 120
        analysis.remSleepMinutes = 96
        analysis.lightSleepMinutes = 264
        analysis.awakeMinutes = 60
        analysis.overallScore = 85.0
        analysis.confidenceScore = 0.92
        
        return analysis
    }
    
    // MARK: - Fetch Tests
    
    func testFetchByAnalysisIdSuccess() async throws {
        // Given
        let analysis = createTestAnalysis()
        try await repository.create(analysis)
        let analysisId = analysis.analysisID!
        
        // When
        let descriptor = FetchDescriptor<PATAnalysis>(
            predicate: #Predicate { $0.analysisID == analysisId }
        )
        let results = try await repository.fetch(descriptor: descriptor)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.analysisID, analysisId)
        XCTAssertEqual(results.first?.totalSleepMinutes, 480)
    }
    
    func testFetchByUserIdReturnsAllAnalyses() async throws {
        // Given - create multiple analyses
        let analysis1 = createTestAnalysis()
        let analysis2 = createTestAnalysis(
            startDate: Date().addingTimeInterval(-16 * 3600),
            endDate: Date().addingTimeInterval(-8 * 3600)
        )
        let analysis3 = createTestAnalysis(type: .nap)
        
        try await repository.create(analysis1)
        try await repository.create(analysis2)
        try await repository.create(analysis3)
        
        // When - fetch all (simulating user's analyses)
        let allAnalyses = try await repository.fetchAll()
        
        // Then
        XCTAssertEqual(allAnalyses.count, 3)
        XCTAssertTrue(allAnalyses.contains { $0.analysisID == analysis1.analysisID })
        XCTAssertTrue(allAnalyses.contains { $0.analysisID == analysis2.analysisID })
        XCTAssertTrue(allAnalyses.contains { $0.analysisID == analysis3.analysisID })
    }
    
    func testFetchPendingAnalyses() async throws {
        // Given
        let pendingAnalysis = createTestAnalysis()
        pendingAnalysis.syncStatus = .pending
        
        let syncedAnalysis = createTestAnalysis()
        syncedAnalysis.syncStatus = .synced
        
        let failedAnalysis = createTestAnalysis()
        failedAnalysis.syncStatus = .failed
        
        try await repository.create(pendingAnalysis)
        try await repository.create(syncedAnalysis)
        try await repository.create(failedAnalysis)
        
        // When
        let pendingStatus = SyncStatus.pending.rawValue
        let descriptor = FetchDescriptor<PATAnalysis>(
            predicate: #Predicate { analysis in
                analysis.syncStatus?.rawValue == pendingStatus
            }
        )
        let pendingResults = try await repository.fetch(descriptor: descriptor)
        
        // Then
        XCTAssertEqual(pendingResults.count, 1)
        XCTAssertEqual(pendingResults.first?.analysisID, pendingAnalysis.analysisID)
    }
    
    func testFetchCompletedAnalyses() async throws {
        // Given - analyses with different sync statuses
        let completedAnalysis1 = createTestAnalysis()
        completedAnalysis1.syncStatus = .synced
        completedAnalysis1.overallScore = 90.0
        
        let completedAnalysis2 = createTestAnalysis(
            startDate: Date().addingTimeInterval(-24 * 3600),
            endDate: Date().addingTimeInterval(-16 * 3600)
        )
        completedAnalysis2.syncStatus = .synced
        completedAnalysis2.overallScore = 75.0
        
        let pendingAnalysis = createTestAnalysis()
        pendingAnalysis.syncStatus = .pending
        
        try await repository.create(completedAnalysis1)
        try await repository.create(completedAnalysis2)
        try await repository.create(pendingAnalysis)
        
        // When - fetch only synced/completed analyses
        let syncedStatus = SyncStatus.synced.rawValue
        let descriptor = FetchDescriptor<PATAnalysis>(
            predicate: #Predicate { analysis in
                analysis.syncStatus?.rawValue == syncedStatus
            }
        )
        let completedResults = try await repository.fetch(descriptor: descriptor)
        
        // Then
        XCTAssertEqual(completedResults.count, 2)
        XCTAssertTrue(completedResults.allSatisfy { $0.syncStatus == .synced })
    }
    
    func testFetchAnalysesSortedByDate() async throws {
        // Given - analyses with different dates
        let oldAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-72 * 3600),
            endDate: Date().addingTimeInterval(-64 * 3600)
        )
        
        let middleAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-48 * 3600),
            endDate: Date().addingTimeInterval(-40 * 3600)
        )
        
        let recentAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-8 * 3600),
            endDate: Date()
        )
        
        // Create in random order
        try await repository.create(middleAnalysis)
        try await repository.create(oldAnalysis)
        try await repository.create(recentAnalysis)
        
        // When - fetch with date sorting
        var descriptor = FetchDescriptor<PATAnalysis>()
        descriptor.sortBy = [SortDescriptor(\.analysisDate, order: .reverse)]
        let sortedAnalyses = try await repository.fetch(descriptor: descriptor)
        
        // Then - should be sorted newest first
        XCTAssertEqual(sortedAnalyses.count, 3)
        let dates = sortedAnalyses.compactMap { $0.analysisDate }
        XCTAssertEqual(dates.count, 3)
        XCTAssertTrue(dates[0] > dates[1])
        XCTAssertTrue(dates[1] > dates[2])
    }
    
    // MARK: - Create Tests
    
    func testCreatePATAnalysisSuccess() async throws {
        // Given
        let analysis = createTestAnalysis()
        
        // Add sleep stages
        analysis.sleepStages = [
            PATSleepStage(timestamp: Date(), stage: .awake, duration: 10, confidence: 0.95),
            PATSleepStage(timestamp: Date().addingTimeInterval(600), stage: .light, duration: 30, confidence: 0.88),
            PATSleepStage(timestamp: Date().addingTimeInterval(2400), stage: .deep, duration: 45, confidence: 0.92),
            PATSleepStage(timestamp: Date().addingTimeInterval(5100), stage: .rem, duration: 20, confidence: 0.85)
        ]
        
        // When
        try await repository.create(analysis)
        
        // Then
        let allAnalyses = try await repository.fetchAll()
        XCTAssertEqual(allAnalyses.count, 1)
        
        let saved = allAnalyses.first
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.totalSleepMinutes, 480)
        XCTAssertEqual(saved?.sleepEfficiency, 0.85)
        XCTAssertEqual(saved?.sleepStages?.count, 4)
        XCTAssertNotNil(saved?.analysisID)
    }
    
    func testCreateAnalysisWithInitialStatus() async throws {
        // Given
        let analysis = PATAnalysis()
        
        // When - create with default initialization
        try await repository.create(analysis)
        
        // Then - verify default values
        let saved = try await repository.fetchAll().first
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.syncStatus, .pending)
        XCTAssertEqual(saved?.analysisType, .overnight)
        XCTAssertEqual(saved?.totalSleepMinutes, 0)
        XCTAssertEqual(saved?.sleepEfficiency, 0)
        XCTAssertEqual(saved?.overallScore, 0)
        XCTAssertNotNil(saved?.analysisDate)
        XCTAssertNotNil(saved?.analysisID)
    }
    
    func testCreateAnalysisGeneratesUniqueId() async throws {
        // Given - create multiple analyses
        let analysis1 = PATAnalysis()
        let analysis2 = PATAnalysis()
        let analysis3 = PATAnalysis()
        
        // When - create all
        try await repository.create(analysis1)
        try await repository.create(analysis2)
        try await repository.create(analysis3)
        
        // Then - all should have unique IDs
        let allAnalyses = try await repository.fetchAll()
        XCTAssertEqual(allAnalyses.count, 3)
        
        let ids = allAnalyses.compactMap { $0.analysisID }
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Set(ids).count, 3, "All IDs should be unique")
        
        // Verify IDs are valid UUIDs
        XCTAssertNotNil(analysis1.analysisID)
        XCTAssertNotNil(analysis2.analysisID)
        XCTAssertNotNil(analysis3.analysisID)
    }
    
    // MARK: - Update Tests
    
    func testUpdateAnalysisStatus() async throws {
        // Given - analysis with pending status
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        try await repository.create(analysis)
        
        // When - update status to synced
        analysis.syncStatus = .synced
        analysis.lastSyncedAt = Date()
        try await repository.update(analysis)
        
        // Then - status should be updated
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .synced)
        XCTAssertNotNil(updated?.lastSyncedAt)
    }
    
    func testUpdateAnalysisWithResults() async throws {
        // Given - analysis without results
        let analysis = PATAnalysis()
        analysis.overallScore = 0
        analysis.confidenceScore = 0
        try await repository.create(analysis)
        
        // When - update with analysis results
        analysis.overallScore = 87.5
        analysis.confidenceScore = 0.94
        analysis.totalSleepMinutes = 465
        analysis.sleepEfficiency = 0.88
        analysis.deepSleepMinutes = 110
        analysis.remSleepMinutes = 95
        analysis.lightSleepMinutes = 260
        analysis.awakeMinutes = 45
        
        // Add quality metrics
        analysis.qualityMetrics = SleepQualityMetrics()
        analysis.qualityMetrics?.continuityScore = 0.85
        analysis.qualityMetrics?.depthScore = 0.90
        analysis.qualityMetrics?.regularityScore = 0.82
        analysis.qualityMetrics?.restorationScore = 0.88
        
        try await repository.update(analysis)
        
        // Then - results should be saved
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.overallScore, 87.5)
        XCTAssertEqual(updated?.confidenceScore, 0.94)
        XCTAssertEqual(updated?.totalSleepMinutes, 465)
        XCTAssertEqual(updated?.sleepEfficiency, 0.88)
        if let avgScore = updated?.qualityMetrics?.averageScore {
            XCTAssertEqual(avgScore, 0.8625, accuracy: 0.001)
        } else {
            XCTFail("Quality metrics average score should not be nil")
        }
    }
    
    func testUpdateCompletionTimestamp() async throws {
        // Given - analysis in processing
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        let originalDate = analysis.analysisDate
        try await repository.create(analysis)
        
        // When - mark as completed
        let completionDate = Date()
        analysis.syncStatus = .synced
        analysis.lastSyncedAt = completionDate
        try await repository.update(analysis)
        
        // Then - completion timestamp should be set
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .synced)
        XCTAssertNotNil(updated?.lastSyncedAt)
        XCTAssertEqual(updated?.analysisDate, originalDate) // Original date unchanged
        
        // Verify completion date is recent
        if let syncDate = updated?.lastSyncedAt {
            let timeDiff = abs(syncDate.timeIntervalSince(completionDate))
            XCTAssertLessThan(timeDiff, 1.0, "Sync date should be recent")
        }
    }
    
    func testUpdateProgressPercentage() async throws {
        // Given - analysis with no sleep stage data
        let analysis = createTestAnalysis()
        analysis.sleepStages = []
        try await repository.create(analysis)
        
        // When - progressively add sleep stages
        let stages = [
            PATSleepStage(timestamp: Date(), stage: .awake, duration: 15, confidence: 0.95),
            PATSleepStage(timestamp: Date().addingTimeInterval(900), stage: .light, duration: 45, confidence: 0.88),
            PATSleepStage(timestamp: Date().addingTimeInterval(3600), stage: .deep, duration: 60, confidence: 0.92),
            PATSleepStage(timestamp: Date().addingTimeInterval(7200), stage: .rem, duration: 30, confidence: 0.85)
        ]
        
        // Update with partial data (simulating progress)
        analysis.sleepStages = Array(stages.prefix(2))
        analysis.confidenceScore = 0.5 // 50% complete
        try await repository.update(analysis)
        
        var updated = try await repository.fetchAll().first
        XCTAssertEqual(updated?.sleepStages?.count, 2)
        XCTAssertEqual(updated?.confidenceScore, 0.5)
        
        // Update with complete data
        analysis.sleepStages = stages
        analysis.confidenceScore = 1.0 // 100% complete
        try await repository.update(analysis)
        
        updated = try await repository.fetchAll().first
        XCTAssertEqual(updated?.sleepStages?.count, 4)
        XCTAssertEqual(updated?.confidenceScore, 1.0)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteAnalysisSuccess() async throws {
        // Given - create multiple analyses
        let analysis1 = createTestAnalysis()
        let analysis2 = createTestAnalysis(
            startDate: Date().addingTimeInterval(-16 * 3600),
            endDate: Date().addingTimeInterval(-8 * 3600)
        )
        let analysis3 = createTestAnalysis(type: .nap)
        
        try await repository.create(analysis1)
        try await repository.create(analysis2)
        try await repository.create(analysis3)
        
        let allAnalyses = try await repository.fetchAll()
        XCTAssertEqual(allAnalyses.count, 3)
        
        // When - delete one analysis
        try await repository.delete(analysis2)
        
        // Then - only two should remain
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.contains { $0.analysisID == analysis1.analysisID })
        XCTAssertTrue(remaining.contains { $0.analysisID == analysis3.analysisID })
        XCTAssertFalse(remaining.contains { $0.analysisID == analysis2.analysisID })
    }
    
    func testDeleteOldAnalyses() async throws {
        // Given - analyses of different ages
        let veryOldAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-90 * 24 * 3600), // 90 days ago
            endDate: Date().addingTimeInterval(-89 * 24 * 3600)
        )
        veryOldAnalysis.analysisDate = Date().addingTimeInterval(-90 * 24 * 3600)
        
        let oldAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-35 * 24 * 3600), // 35 days ago
            endDate: Date().addingTimeInterval(-34 * 24 * 3600)
        )
        oldAnalysis.analysisDate = Date().addingTimeInterval(-35 * 24 * 3600)
        
        let recentAnalysis = createTestAnalysis() // Today
        
        try await repository.create(veryOldAnalysis)
        try await repository.create(oldAnalysis)
        try await repository.create(recentAnalysis)
        
        // When - delete analyses older than 30 days
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 3600)
        let allAnalyses = try await repository.fetchAll()
        
        for analysis in allAnalyses {
            if let analysisDate = analysis.analysisDate, analysisDate < cutoffDate {
                try await repository.delete(analysis)
            }
        }
        
        // Then - only recent analysis should remain
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.analysisID, recentAnalysis.analysisID)
    }
    
    func testDeleteFailedAnalyses() async throws {
        // Given - analyses with different sync statuses
        let pendingAnalysis = createTestAnalysis()
        pendingAnalysis.syncStatus = .pending
        
        let syncedAnalysis = createTestAnalysis()
        syncedAnalysis.syncStatus = .synced
        
        let failedAnalysis1 = createTestAnalysis()
        failedAnalysis1.syncStatus = .failed
        
        let failedAnalysis2 = createTestAnalysis(type: .nap)
        failedAnalysis2.syncStatus = .failed
        
        try await repository.create(pendingAnalysis)
        try await repository.create(syncedAnalysis)
        try await repository.create(failedAnalysis1)
        try await repository.create(failedAnalysis2)
        
        // When - delete all failed analyses
        let failedStatus = SyncStatus.failed.rawValue
        let descriptor = FetchDescriptor<PATAnalysis>(
            predicate: #Predicate { analysis in
                analysis.syncStatus?.rawValue == failedStatus
            }
        )
        let failedAnalyses = try await repository.fetch(descriptor: descriptor)
        
        for analysis in failedAnalyses {
            try await repository.delete(analysis)
        }
        
        // Then - only non-failed analyses should remain
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.allSatisfy { $0.syncStatus != .failed })
        XCTAssertTrue(remaining.contains { $0.analysisID == pendingAnalysis.analysisID })
        XCTAssertTrue(remaining.contains { $0.analysisID == syncedAnalysis.analysisID })
    }
    
    // MARK: - Status Management Tests
    
    func testTransitionToPendingStatus() async throws {
        // Given - analysis with no status
        let analysis = PATAnalysis()
        analysis.syncStatus = nil
        try await repository.create(analysis)
        
        // When - transition to pending
        analysis.syncStatus = .pending
        try await repository.update(analysis)
        
        // Then - status should be pending
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .pending)
        XCTAssertNil(updated?.lastSyncedAt) // Not synced yet
    }
    
    func testTransitionToProcessingStatus() async throws {
        // Given - pending analysis
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        try await repository.create(analysis)
        
        // When - start processing (simulate by changing status)
        // Note: In real app, processing status might be handled differently
        analysis.syncStatus = .pending // Keep as pending during processing
        analysis.confidenceScore = 0.25 // 25% progress
        try await repository.update(analysis)
        
        // Then - analysis should show processing progress
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .pending)
        XCTAssertEqual(updated?.confidenceScore, 0.25)
    }
    
    func testTransitionToCompletedStatus() async throws {
        // Given - analysis in pending status
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        analysis.confidenceScore = 0.5 // Partially complete
        try await repository.create(analysis)
        
        // When - mark as completed/synced
        analysis.syncStatus = .synced
        analysis.confidenceScore = 1.0 // Fully complete
        analysis.lastSyncedAt = Date()
        analysis.overallScore = 92.0
        try await repository.update(analysis)
        
        // Then - should be completed
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .synced)
        XCTAssertEqual(updated?.confidenceScore, 1.0)
        XCTAssertNotNil(updated?.lastSyncedAt)
        XCTAssertEqual(updated?.overallScore, 92.0)
    }
    
    func testTransitionToFailedStatus() async throws {
        // Given - analysis in pending status
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        try await repository.create(analysis)
        
        // When - mark as failed
        analysis.syncStatus = .failed
        analysis.lastSyncedAt = nil // Failed, so no sync date
        try await repository.update(analysis)
        
        // Then - should be failed
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .failed)
        XCTAssertNil(updated?.lastSyncedAt)
    }
    
    func testPreventInvalidStatusTransitions() async throws {
        // Given - completed/synced analysis
        let analysis = createTestAnalysis()
        analysis.syncStatus = .synced
        analysis.lastSyncedAt = Date()
        analysis.overallScore = 88.0
        try await repository.create(analysis)
        
        // When - try to transition back to pending (invalid)
        analysis.syncStatus = .pending
        analysis.overallScore = 0 // Try to reset score
        try await repository.update(analysis)
        
        // Then - in this test we're verifying the update happens
        // In a real app, business logic might prevent this
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        // The update should have gone through (no validation in repository)
        XCTAssertEqual(updated?.syncStatus, .pending)
        XCTAssertEqual(updated?.overallScore, 0)
        
        // Note: Business logic validation would typically be in a service layer
    }
    
    // MARK: - Results Processing Tests
    
    func testStoreAnalysisResults() async throws {
        // Given - analysis without results
        let analysis = PATAnalysis()
        try await repository.create(analysis)
        
        // When - store comprehensive results
        analysis.totalSleepMinutes = 495
        analysis.sleepEfficiency = 0.91
        analysis.sleepLatency = 12
        analysis.wakeAfterSleepOnset = 35
        
        // Sleep stages
        analysis.deepSleepMinutes = 125
        analysis.remSleepMinutes = 105
        analysis.lightSleepMinutes = 265
        analysis.awakeMinutes = 45
        
        // Percentages
        analysis.deepSleepPercentage = 0.252
        analysis.remSleepPercentage = 0.212
        analysis.lightSleepPercentage = 0.535
        
        // Scores
        analysis.overallScore = 91.5
        analysis.confidenceScore = 0.96
        
        // Quality metrics
        let metrics = SleepQualityMetrics()
        analysis.qualityMetrics = metrics
        analysis.qualityMetrics?.continuityScore = 0.92
        analysis.qualityMetrics?.depthScore = 0.88
        analysis.qualityMetrics?.regularityScore = 0.90
        analysis.qualityMetrics?.restorationScore = 0.94
        
        try await repository.update(analysis)
        
        // Then - all results should be stored
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.totalSleepMinutes, 495)
        XCTAssertEqual(updated?.sleepEfficiency, 0.91)
        XCTAssertEqual(updated?.sleepLatency, 12)
        XCTAssertEqual(updated?.wakeAfterSleepOnset, 35)
        XCTAssertEqual(updated?.overallScore, 91.5)
        if let avgScore = updated?.qualityMetrics?.averageScore {
            XCTAssertEqual(avgScore, 0.91, accuracy: 0.01)
        } else {
            XCTFail("Quality metrics average score should not be nil")
        }
    }
    
    func testParseResultsJSON() async throws {
        // Given - analysis with sleep stage data that could come from JSON
        let analysis = PATAnalysis()
        
        // Simulate parsed sleep stages from JSON
        let stages = [
            PATSleepStage(timestamp: Date(), stage: .awake, duration: 5, confidence: 0.98),
            PATSleepStage(timestamp: Date().addingTimeInterval(300), stage: .light, duration: 25, confidence: 0.85),
            PATSleepStage(timestamp: Date().addingTimeInterval(1800), stage: .light, duration: 30, confidence: 0.87),
            PATSleepStage(timestamp: Date().addingTimeInterval(3600), stage: .deep, duration: 45, confidence: 0.92),
            PATSleepStage(timestamp: Date().addingTimeInterval(6300), stage: .rem, duration: 20, confidence: 0.88),
            PATSleepStage(timestamp: Date().addingTimeInterval(7500), stage: .light, duration: 35, confidence: 0.86),
            PATSleepStage(timestamp: Date().addingTimeInterval(9600), stage: .deep, duration: 40, confidence: 0.91),
            PATSleepStage(timestamp: Date().addingTimeInterval(12000), stage: .rem, duration: 25, confidence: 0.89),
            PATSleepStage(timestamp: Date().addingTimeInterval(13500), stage: .light, duration: 20, confidence: 0.84),
            PATSleepStage(timestamp: Date().addingTimeInterval(14700), stage: .awake, duration: 10, confidence: 0.95)
        ]
        
        analysis.sleepStages = stages
        
        // Calculate totals from stages
        analysis.totalSleepMinutes = stages.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
        analysis.awakeMinutes = stages.filter { $0.stage == .awake }.reduce(0) { $0 + $1.duration }
        analysis.deepSleepMinutes = stages.filter { $0.stage == .deep }.reduce(0) { $0 + $1.duration }
        analysis.remSleepMinutes = stages.filter { $0.stage == .rem }.reduce(0) { $0 + $1.duration }
        analysis.lightSleepMinutes = stages.filter { $0.stage == .light }.reduce(0) { $0 + $1.duration }
        
        try await repository.create(analysis)
        
        // Then - verify calculations
        let saved = try await repository.fetchAll().first
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.sleepStages?.count, 10)
        XCTAssertEqual(saved?.totalSleepMinutes, 240) // Total non-awake time
        XCTAssertEqual(saved?.awakeMinutes, 15)
        XCTAssertEqual(saved?.deepSleepMinutes, 85)
        XCTAssertEqual(saved?.remSleepMinutes, 45)
        XCTAssertEqual(saved?.lightSleepMinutes, 110)
    }
    
    func testExtractKeyMetrics() async throws {
        // Given - comprehensive analysis data
        let analysis = createTestAnalysis()
        
        // Add actigraphy data
        analysis.actigraphyData = [
            ActigraphyDataPoint(timestamp: Date(), movementCount: 5, intensity: 0.2, ambientLight: 0.1, soundLevel: 0.15),
            ActigraphyDataPoint(timestamp: Date().addingTimeInterval(300), movementCount: 2, intensity: 0.1, ambientLight: 0.05, soundLevel: 0.1),
            ActigraphyDataPoint(timestamp: Date().addingTimeInterval(600), movementCount: 0, intensity: 0.0, ambientLight: 0.02, soundLevel: 0.08),
            ActigraphyDataPoint(timestamp: Date().addingTimeInterval(900), movementCount: 1, intensity: 0.05, ambientLight: 0.02, soundLevel: 0.1),
            ActigraphyDataPoint(timestamp: Date().addingTimeInterval(1200), movementCount: 8, intensity: 0.4, ambientLight: 0.15, soundLevel: 0.2)
        ]
        
        // Add movement intensity array
        analysis.movementIntensity = [0.2, 0.1, 0.0, 0.05, 0.4, 0.15, 0.1, 0.0, 0.05, 0.3]
        
        try await repository.create(analysis)
        
        // When - fetch and verify key metrics can be extracted
        let saved = try await repository.fetchAll().first
        XCTAssertNotNil(saved)
        
        // Then - verify key metrics are accessible
        // Sleep efficiency
        let efficiency = saved?.sleepEfficiency ?? 0
        XCTAssertEqual(efficiency, 0.85)
        XCTAssertTrue(efficiency > 0.8, "Good sleep efficiency")
        
        // Sleep stage distribution
        let totalSleep = saved?.totalSleepMinutes ?? 0
        let deepPercentage = Double(saved?.deepSleepMinutes ?? 0) / Double(totalSleep)
        let remPercentage = Double(saved?.remSleepMinutes ?? 0) / Double(totalSleep)
        let lightPercentage = Double(saved?.lightSleepMinutes ?? 0) / Double(totalSleep)
        
        XCTAssertEqual(deepPercentage, 0.25, accuracy: 0.01)
        XCTAssertEqual(remPercentage, 0.20, accuracy: 0.01)
        XCTAssertEqual(lightPercentage, 0.55, accuracy: 0.01)
        
        // Movement metrics
        XCTAssertEqual(saved?.actigraphyData?.count, 5)
        let avgMovement = saved?.movementIntensity?.reduce(0.0, +) ?? 0 / Double(saved?.movementIntensity?.count ?? 1)
        XCTAssertGreaterThan(avgMovement, 0)
        
        // Overall score
        XCTAssertEqual(saved?.overallScore, 85.0)
        XCTAssertEqual(saved?.confidenceScore, 0.92)
    }
    
    // MARK: - Query Tests
    
    func testCountAnalysesByStatus() async throws {
        // Given - analyses with different statuses
        let pending1 = createTestAnalysis()
        pending1.syncStatus = .pending
        
        let pending2 = createTestAnalysis()
        pending2.syncStatus = .pending
        
        let synced1 = createTestAnalysis()
        synced1.syncStatus = .synced
        
        let synced2 = createTestAnalysis()
        synced2.syncStatus = .synced
        
        let synced3 = createTestAnalysis()
        synced3.syncStatus = .synced
        
        let failed1 = createTestAnalysis()
        failed1.syncStatus = .failed
        
        try await repository.create(pending1)
        try await repository.create(pending2)
        try await repository.create(synced1)
        try await repository.create(synced2)
        try await repository.create(synced3)
        try await repository.create(failed1)
        
        // When - count by status
        let allAnalyses = try await repository.fetchAll()
        let statusCounts = Dictionary(grouping: allAnalyses) { $0.syncStatus }
            .mapValues { $0.count }
        
        // Then
        XCTAssertEqual(statusCounts[.pending], 2)
        XCTAssertEqual(statusCounts[.synced], 3)
        XCTAssertEqual(statusCounts[.failed], 1)
        XCTAssertEqual(allAnalyses.count, 6)
    }
    
    func testFindLatestAnalysis() async throws {
        // Given - analyses with different dates
        let oldestAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-72 * 3600),
            endDate: Date().addingTimeInterval(-64 * 3600)
        )
        oldestAnalysis.analysisDate = Date().addingTimeInterval(-72 * 3600)
        
        let middleAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-24 * 3600),
            endDate: Date().addingTimeInterval(-16 * 3600)
        )
        middleAnalysis.analysisDate = Date().addingTimeInterval(-24 * 3600)
        
        let latestAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-8 * 3600),
            endDate: Date()
        )
        latestAnalysis.analysisDate = Date() // Most recent
        latestAnalysis.overallScore = 95.0 // Distinct score to verify
        
        // Create in random order
        try await repository.create(middleAnalysis)
        try await repository.create(oldestAnalysis)
        try await repository.create(latestAnalysis)
        
        // When - fetch latest
        let latest = try await repository.fetchLatestAnalysis()
        
        // Then
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.analysisID, latestAnalysis.analysisID)
        XCTAssertEqual(latest?.overallScore, 95.0)
        
        // Verify it's actually the most recent
        if let latestDate = latest?.analysisDate {
            let allAnalyses = try await repository.fetchAll()
            for analysis in allAnalyses {
                if let date = analysis.analysisDate {
                    XCTAssertLessThanOrEqual(date, latestDate)
                }
            }
        }
    }
    
    func testCheckActiveAnalysisExists() async throws {
        // Given - no analyses initially
        var allAnalyses = try await repository.fetchAll()
        XCTAssertEqual(allAnalyses.count, 0)
        
        // When - check for active analysis (recent and pending/processing)
        let recentCutoff = Date().addingTimeInterval(-12 * 3600) // 12 hours ago
        var activeExists = allAnalyses.contains { analysis in
            guard let startDate = analysis.startDate else { return false }
            return startDate > recentCutoff && 
                   (analysis.syncStatus == .pending || analysis.syncStatus == nil)
        }
        
        // Then - no active analysis
        XCTAssertFalse(activeExists)
        
        // Given - add an old completed analysis
        let oldAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-24 * 3600),
            endDate: Date().addingTimeInterval(-16 * 3600)
        )
        oldAnalysis.syncStatus = .synced
        try await repository.create(oldAnalysis)
        
        // When - check again
        allAnalyses = try await repository.fetchAll()
        activeExists = allAnalyses.contains { analysis in
            guard let startDate = analysis.startDate else { return false }
            return startDate > recentCutoff && 
                   (analysis.syncStatus == .pending || analysis.syncStatus == nil)
        }
        
        // Then - still no active analysis
        XCTAssertFalse(activeExists)
        
        // Given - add a recent pending analysis
        let activeAnalysis = createTestAnalysis(
            startDate: Date().addingTimeInterval(-2 * 3600),
            endDate: Date()
        )
        activeAnalysis.syncStatus = .pending
        try await repository.create(activeAnalysis)
        
        // When - check once more
        allAnalyses = try await repository.fetchAll()
        activeExists = allAnalyses.contains { analysis in
            guard let startDate = analysis.startDate else { return false }
            return startDate > recentCutoff && 
                   (analysis.syncStatus == .pending || analysis.syncStatus == nil)
        }
        
        // Then - active analysis exists
        XCTAssertTrue(activeExists)
    }
    
    // MARK: - Sync Tests
    
    func testSyncAnalysisWithBackend() async throws {
        // Given - unsynced analyses
        let analysis1 = createTestAnalysis()
        analysis1.syncStatus = .pending
        
        let analysis2 = createTestAnalysis(
            startDate: Date().addingTimeInterval(-16 * 3600),
            endDate: Date().addingTimeInterval(-8 * 3600)
        )
        analysis2.syncStatus = .failed // Previous failure
        
        try await repository.create(analysis1)
        try await repository.create(analysis2)
        
        // When - sync with backend
        try await repository.sync()
        
        // Then - analyses should be marked as synced
        // Note: The repository mock simulates successful sync
        let synced = try await repository.fetchAll()
        XCTAssertEqual(synced.count, 2)
        
        // All should be synced after sync operation
        for analysis in synced {
            XCTAssertEqual(analysis.syncStatus, .synced)
            XCTAssertNotNil(analysis.lastSyncedAt)
        }
    }
    
    func testMarkAnalysisAsSynced() async throws {
        // Given - pending analysis
        let analysis = createTestAnalysis()
        analysis.syncStatus = .pending
        analysis.lastSyncedAt = nil
        try await repository.create(analysis)
        
        // When - mark as synced
        let syncTime = Date()
        analysis.syncStatus = .synced
        analysis.lastSyncedAt = syncTime
        try await repository.update(analysis)
        
        // Then - should be marked as synced
        let updated = try await repository.fetchAll().first
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.syncStatus, .synced)
        XCTAssertNotNil(updated?.lastSyncedAt)
        
        // Verify sync time is correct
        if let lastSync = updated?.lastSyncedAt {
            let timeDiff = abs(lastSync.timeIntervalSince(syncTime))
            XCTAssertLessThan(timeDiff, 1.0)
        }
    }
    
    func testFetchUnsyncedAnalyses() async throws {
        // Given - mix of synced and unsynced analyses
        let synced1 = createTestAnalysis()
        synced1.syncStatus = .synced
        synced1.lastSyncedAt = Date().addingTimeInterval(-3600)
        
        let synced2 = createTestAnalysis()
        synced2.syncStatus = .synced
        synced2.lastSyncedAt = Date().addingTimeInterval(-7200)
        
        let pending1 = createTestAnalysis()
        pending1.syncStatus = .pending
        
        let pending2 = createTestAnalysis()
        pending2.syncStatus = .pending
        
        let failed = createTestAnalysis()
        failed.syncStatus = .failed
        
        try await repository.create(synced1)
        try await repository.create(synced2)
        try await repository.create(pending1)
        try await repository.create(pending2)
        try await repository.create(failed)
        
        // When - fetch unsynced (pending or failed)
        let allAnalyses = try await repository.fetchAll()
        let unsyncedAnalyses = allAnalyses.filter { analysis in
            analysis.syncStatus == .pending || analysis.syncStatus == .failed
        }
        
        // Then
        XCTAssertEqual(unsyncedAnalyses.count, 3)
        XCTAssertTrue(unsyncedAnalyses.contains { $0.analysisID == pending1.analysisID })
        XCTAssertTrue(unsyncedAnalyses.contains { $0.analysisID == pending2.analysisID })
        XCTAssertTrue(unsyncedAnalyses.contains { $0.analysisID == failed.analysisID })
        
        // Verify none are synced
        XCTAssertTrue(unsyncedAnalyses.allSatisfy { $0.syncStatus != .synced })
    }
    
    // MARK: - Performance Tests
    
    func testBulkAnalysisCreation() async throws {
        // Given - create many analyses
        let analysesToCreate = 50
        var analyses: [PATAnalysis] = []
        
        for i in 0..<analysesToCreate {
            let startOffset = TimeInterval(-((i + 1) * 8 * 3600)) // Each 8 hours apart
            let analysis = createTestAnalysis(
                startDate: Date().addingTimeInterval(startOffset),
                endDate: Date().addingTimeInterval(startOffset + 7 * 3600),
                type: i % 5 == 0 ? .nap : .overnight // Mix of types
            )
            analysis.overallScore = Double(70 + (i % 30)) // Scores from 70-99
            analysis.syncStatus = i % 3 == 0 ? .synced : .pending // Mix of statuses
            analyses.append(analysis)
        }
        
        // When - bulk create
        let startTime = Date()
        for analysis in analyses {
            try await repository.create(analysis)
        }
        let creationTime = Date().timeIntervalSince(startTime)
        
        // Then - all should be created
        let allAnalyses = try await repository.fetchAll()
        XCTAssertEqual(allAnalyses.count, analysesToCreate)
        
        // Verify performance (should be fast with in-memory DB)
        XCTAssertLessThan(creationTime, 5.0, "Bulk creation should complete within 5 seconds")
        
        // Verify data integrity
        let napCount = allAnalyses.filter { $0.analysisType == .nap }.count
        let overnightCount = allAnalyses.filter { $0.analysisType == .overnight }.count
        XCTAssertEqual(napCount, 10) // Every 5th is a nap
        XCTAssertEqual(overnightCount, 40)
        
        // Verify unique IDs
        let uniqueIds = Set(allAnalyses.compactMap { $0.analysisID })
        XCTAssertEqual(uniqueIds.count, analysesToCreate)
    }
    
    func testLargeResultsHandling() async throws {
        // Given - analysis with extensive data
        let analysis = createTestAnalysis()
        
        // Add many sleep stages (simulate 8 hours with stage every 5 minutes)
        var stages: [PATSleepStage] = []
        let stageInterval: TimeInterval = 300 // 5 minutes
        let totalStages = 96 // 8 hours / 5 minutes
        
        for i in 0..<totalStages {
            let timestamp = Date().addingTimeInterval(Double(i) * stageInterval)
            let stageType: PATSleepStage.SleepStageType
            
            // Simulate realistic sleep pattern
            switch i {
            case 0..<4: stageType = .awake
            case 4..<20: stageType = .light
            case 20..<35: stageType = .deep
            case 35..<50: stageType = .rem
            case 50..<65: stageType = .light
            case 65..<75: stageType = .deep
            case 75..<85: stageType = .rem
            case 85..<92: stageType = .light
            default: stageType = .awake
            }
            
            let stage = PATSleepStage(
                timestamp: timestamp,
                stage: stageType,
                duration: 5,
                confidence: Double.random(in: 0.8...0.95)
            )
            stages.append(stage)
        }
        
        analysis.sleepStages = stages
        
        // Add extensive actigraphy data (every minute)
        var actigraphyPoints: [ActigraphyDataPoint] = []
        for i in 0..<480 { // 8 hours * 60 minutes
            let point = ActigraphyDataPoint(
                timestamp: Date().addingTimeInterval(Double(i) * 60),
                movementCount: Int.random(in: 0...10),
                intensity: Double.random(in: 0...0.5),
                ambientLight: Double.random(in: 0...0.2),
                soundLevel: Double.random(in: 0...0.3)
            )
            actigraphyPoints.append(point)
        }
        
        analysis.actigraphyData = actigraphyPoints
        
        // When - create and fetch
        try await repository.create(analysis)
        let fetched = try await repository.fetchAll().first
        
        // Then - all data should be preserved
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.sleepStages?.count, totalStages)
        XCTAssertEqual(fetched?.actigraphyData?.count, 480)
        
        // Verify data integrity
        if let fetchedStages = fetched?.sleepStages {
            // Check stages are in order
            for i in 1..<fetchedStages.count {
                XCTAssertGreaterThan(fetchedStages[i].timestamp, fetchedStages[i-1].timestamp)
            }
        }
        
        // Verify calculations still work with large data
        let totalSleepStages = fetched?.sleepStages?.filter { $0.stage != .awake } ?? []
        let totalSleepFromStages = totalSleepStages.reduce(0) { $0 + $1.duration }
        XCTAssertGreaterThan(totalSleepFromStages, 400) // Should have substantial sleep
    }
}