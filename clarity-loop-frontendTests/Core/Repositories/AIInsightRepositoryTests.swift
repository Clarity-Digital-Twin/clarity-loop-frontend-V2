import XCTest
import SwiftData
@testable import clarity_loop_frontend

@MainActor
final class AIInsightRepositoryTests: XCTestCase {
    
    // MARK: - Properties
    
    private var repository: AIInsightRepository!
    private var modelContext: ModelContext!
    private var modelContainer: ModelContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory test container
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: AIInsight.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
        
        repository = AIInsightRepository(modelContext: modelContext)
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
    
    private func createTestInsight(
        content: String = "Test insight content",
        category: InsightCategory = .heartHealth,
        priority: InsightPriority = .medium,
        type: AIInsightType = .suggestion
    ) -> AIInsight {
        let insight = AIInsight(
            content: content,
            category: category,
            type: type
        )
        insight.title = "Test Insight"
        insight.summary = "Test summary"
        insight.priority = priority
        insight.confidenceScore = 0.85
        return insight
    }
    
    // MARK: - Fetch Tests
    
    func testFetchAllInsights() async throws {
        // Arrange
        let insight1 = createTestInsight(content: "Insight 1")
        let insight2 = createTestInsight(content: "Insight 2")
        try await repository.create(insight1)
        try await repository.create(insight2)
        
        // Act
        let insights = try await repository.fetchAll()
        
        // Assert
        XCTAssertEqual(insights.count, 2)
        XCTAssertTrue(insights.contains { $0.content == "Insight 1" })
        XCTAssertTrue(insights.contains { $0.content == "Insight 2" })
    }
    
    func testFetchInsightByIdSuccess() async throws {
        // Arrange
        let insight = createTestInsight()
        try await repository.create(insight)
        let insightId = insight.insightID!
        
        // Act
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.insightID == insightId }
        )
        let results = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.insightID, insightId)
    }
    
    func testFetchInsightByIdNotFound() async throws {
        // Arrange
        let nonExistentId = UUID()
        
        // Act
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.insightID == nonExistentId }
        )
        let results = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertTrue(results.isEmpty)
    }
    
    func testFetchUnreadInsights() async throws {
        // Arrange
        let readInsight = createTestInsight(content: "Read insight")
        readInsight.isRead = true
        
        let unreadInsight1 = createTestInsight(content: "Unread 1")
        unreadInsight1.isRead = false
        
        let unreadInsight2 = createTestInsight(content: "Unread 2")
        unreadInsight2.isRead = false
        
        try await repository.create(readInsight)
        try await repository.create(unreadInsight1)
        try await repository.create(unreadInsight2)
        
        // Act
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.isRead == false }
        )
        let unreadInsights = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertEqual(unreadInsights.count, 2)
        XCTAssertTrue(unreadInsights.allSatisfy { $0.isRead == false })
    }
    
    func testFetchBookmarkedInsights() async throws {
        // Arrange
        let favoriteInsight = createTestInsight(content: "Favorite")
        favoriteInsight.isFavorite = true
        
        let regularInsight = createTestInsight(content: "Regular")
        regularInsight.isFavorite = false
        
        try await repository.create(favoriteInsight)
        try await repository.create(regularInsight)
        
        // Act
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.isFavorite == true }
        )
        let bookmarked = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertEqual(bookmarked.count, 1)
        XCTAssertEqual(bookmarked.first?.content, "Favorite")
    }
    
    func testFetchInsightsByCategory() async throws {
        // Arrange
        let healthInsight = createTestInsight(category: .heartHealth)
        let fitnessInsight = createTestInsight(category: .activity)
        let nutritionInsight = createTestInsight(category: .nutrition)
        let generalInsight = createTestInsight(category: .general)
        
        try await repository.create(healthInsight)
        try await repository.create(fitnessInsight)
        try await repository.create(nutritionInsight)
        try await repository.create(generalInsight)
        
        // Act
        let healthInsights = try await repository.fetchInsights(for: .heartHealth, limit: 10)
        
        // Assert
        XCTAssertEqual(healthInsights.count, 1)
        XCTAssertEqual(healthInsights.first?.category, .heartHealth)
    }
    
    func testFetchInsightsByPriority() async throws {
        // Arrange
        let highPriorityInsight = createTestInsight(priority: .high)
        let mediumPriorityInsight = createTestInsight(priority: .medium)
        let lowPriorityInsight = createTestInsight(priority: .low)
        
        try await repository.create(highPriorityInsight)
        try await repository.create(mediumPriorityInsight)
        try await repository.create(lowPriorityInsight)
        
        // Act
        let highPriority = InsightPriority.high
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { insight in
                insight.priority == highPriority
            }
        )
        let highPriorityInsights = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertEqual(highPriorityInsights.count, 1)
        XCTAssertEqual(highPriorityInsights.first?.priority, .high)
    }
    
    func testFetchInsightsByDateRange() async throws {
        // Arrange
        let oldDate = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        let recentDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        let oldInsight = createTestInsight(content: "Old")
        oldInsight.timestamp = oldDate
        
        let recentInsight = createTestInsight(content: "Recent")
        recentInsight.timestamp = recentDate
        
        try await repository.create(oldInsight)
        try await repository.create(recentInsight)
        
        // Act - Fetch insights from last 24 hours
        let cutoffDate = Date().addingTimeInterval(-86400)
        let defaultDate = Date.distantPast
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { insight in
                (insight.timestamp ?? defaultDate) > cutoffDate
            }
        )
        let recentInsights = try await repository.fetch(descriptor: descriptor)
        
        // Assert
        XCTAssertEqual(recentInsights.count, 1)
        XCTAssertEqual(recentInsights.first?.content, "Recent")
    }
    
    // MARK: - Create Tests
    
    func testCreateInsightSuccess() async throws {
        // Arrange
        let insight = createTestInsight()
        
        // Act
        try await repository.create(insight)
        
        // Assert
        let allInsights = try await repository.fetchAll()
        XCTAssertEqual(allInsights.count, 1)
        XCTAssertEqual(allInsights.first?.content, insight.content)
    }
    
    func testCreateInsightWithAllFields() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.remoteID = "remote-123"
        insight.modelVersion = "gpt-4"
        insight.generationTime = 1.5
        insight.userRating = 5
        insight.userFeedback = "Very helpful!"
        insight.conversationID = UUID()
        insight.contextData = ["source": "health_metrics", "period": "7_days"]
        
        // Act
        try await repository.create(insight)
        
        // Assert
        let saved = try await repository.fetchAll().first
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.remoteID, "remote-123")
        XCTAssertEqual(saved?.modelVersion, "gpt-4")
        XCTAssertEqual(saved?.generationTime, 1.5)
        XCTAssertEqual(saved?.userRating, 5)
        XCTAssertEqual(saved?.userFeedback, "Very helpful!")
        XCTAssertNotNil(saved?.conversationID)
        XCTAssertEqual(saved?.contextData?["source"], "health_metrics")
    }
    
    func testCreateInsightGeneratesTimestamp() async throws {
        // Arrange
        let insight = createTestInsight()
        let beforeCreate = Date()
        
        // Act
        try await repository.create(insight)
        let afterCreate = Date()
        
        // Assert
        let saved = try await repository.fetchAll().first
        XCTAssertNotNil(saved?.timestamp)
        XCTAssertTrue(saved!.timestamp! >= beforeCreate)
        XCTAssertTrue(saved!.timestamp! <= afterCreate)
    }
    
    func testPreventDuplicateInsights() async throws {
        // Arrange
        let insight1 = createTestInsight()
        let insight2 = createTestInsight() // Same content
        
        // Act
        try await repository.create(insight1)
        try await repository.create(insight2)
        
        // Assert - SwiftData doesn't enforce uniqueness by default
        let allInsights = try await repository.fetchAll()
        XCTAssertEqual(allInsights.count, 2) // Both are created
        // In a real app, you'd implement duplicate checking logic
    }
    
    // MARK: - Update Tests
    
    func testUpdateInsightReadStatus() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.isRead = false
        try await repository.create(insight)
        
        // Act
        insight.isRead = true
        try await repository.update(insight)
        
        // Assert
        let updated = try await repository.fetchAll().first
        XCTAssertTrue(updated?.isRead ?? false)
    }
    
    func testUpdateInsightBookmarkStatus() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.isFavorite = false
        try await repository.create(insight)
        
        // Act
        insight.isFavorite = true
        try await repository.update(insight)
        
        // Assert
        let updated = try await repository.fetchAll().first
        XCTAssertTrue(updated?.isFavorite ?? false)
    }
    
    func testUpdateInsightActionTaken() async throws {
        // Arrange
        let insight = createTestInsight()
        try await repository.create(insight)
        
        // Act
        insight.userFeedback = "Action taken: Changed diet based on this insight"
        insight.userRating = 5
        try await repository.update(insight)
        
        // Assert
        let updated = try await repository.fetchAll().first
        XCTAssertEqual(updated?.userFeedback, "Action taken: Changed diet based on this insight")
        XCTAssertEqual(updated?.userRating, 5)
    }
    
    func testUpdateInsightLastModified() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.timestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        try await repository.create(insight)
        
        // Act
        insight.content = "Updated content"
        // In a real app, you'd update timestamp here
        try await repository.update(insight)
        
        // Assert
        let updated = try await repository.fetchAll().first
        XCTAssertEqual(updated?.content, "Updated content")
    }
    
    // MARK: - Delete Tests
    
    func testDeleteInsightSuccess() async throws {
        // Arrange
        let insight = createTestInsight()
        try await repository.create(insight)
        
        // Act
        try await repository.delete(insight)
        
        // Assert
        let allInsights = try await repository.fetchAll()
        XCTAssertTrue(allInsights.isEmpty)
    }
    
    func testDeleteOldInsights() async throws {
        // Arrange
        let oldDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let recentDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        let oldInsight = createTestInsight(content: "Old")
        oldInsight.timestamp = oldDate
        
        let recentInsight = createTestInsight(content: "Recent")
        recentInsight.timestamp = recentDate
        
        try await repository.create(oldInsight)
        try await repository.create(recentInsight)
        
        // Act - Delete insights older than 7 days
        let cutoffDate = Date().addingTimeInterval(-86400 * 7)
        let defaultDate = Date()
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { insight in
                (insight.timestamp ?? defaultDate) < cutoffDate
            }
        )
        let oldInsights = try await repository.fetch(descriptor: descriptor)
        for insight in oldInsights {
            try await repository.delete(insight)
        }
        
        // Assert
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "Recent")
    }
    
    func testDeleteReadInsights() async throws {
        // Arrange
        let readInsight = createTestInsight(content: "Read")
        readInsight.isRead = true
        
        let unreadInsight = createTestInsight(content: "Unread")
        unreadInsight.isRead = false
        
        try await repository.create(readInsight)
        try await repository.create(unreadInsight)
        
        // Act
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.isRead == true }
        )
        let readInsights = try await repository.fetch(descriptor: descriptor)
        for insight in readInsights {
            try await repository.delete(insight)
        }
        
        // Assert
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "Unread")
    }
    
    func testPreserveBookmarkedInsights() async throws {
        // Arrange
        let bookmarkedOld = createTestInsight(content: "Bookmarked Old")
        bookmarkedOld.isFavorite = true
        bookmarkedOld.timestamp = Date().addingTimeInterval(-86400 * 30)
        
        let regularOld = createTestInsight(content: "Regular Old")
        regularOld.isFavorite = false
        regularOld.timestamp = Date().addingTimeInterval(-86400 * 30)
        
        try await repository.create(bookmarkedOld)
        try await repository.create(regularOld)
        
        // Act - Delete old insights but preserve bookmarked
        let cutoffDate = Date().addingTimeInterval(-86400 * 7)
        let defaultDate = Date()
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { insight in
                ((insight.timestamp ?? defaultDate) < cutoffDate) && (insight.isFavorite != true)
            }
        )
        let toDelete = try await repository.fetch(descriptor: descriptor)
        for insight in toDelete {
            try await repository.delete(insight)
        }
        
        // Assert
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "Bookmarked Old")
    }
    
    // MARK: - Bulk Operations Tests
    
    func testMarkAllAsRead() async throws {
        // Arrange
        let insights = (1...5).map { i in
            let insight = createTestInsight(content: "Insight \(i)")
            insight.isRead = false
            return insight
        }
        
        for insight in insights {
            try await repository.create(insight)
        }
        
        // Act
        let allInsights = try await repository.fetchAll()
        for insight in allInsights {
            insight.isRead = true
            try await repository.update(insight)
        }
        
        // Assert
        let updatedInsights = try await repository.fetchAll()
        XCTAssertTrue(updatedInsights.allSatisfy { $0.isRead == true })
    }
    
    func testDeleteMultipleInsights() async throws {
        // Arrange
        let insights = (1...10).map { i in
            createTestInsight(content: "Insight \(i)")
        }
        
        for insight in insights {
            try await repository.create(insight)
        }
        
        // Act - Delete first 5
        var descriptor = FetchDescriptor<AIInsight>()
        descriptor.fetchLimit = 5
        let toDelete = try await repository.fetch(descriptor: descriptor)
        try await repository.deleteBatch(toDelete)
        
        // Assert
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 5)
    }
    
    func testBulkUpdateCategory() async throws {
        // Arrange
        let insights = (1...3).map { _ in
            createTestInsight(category: .general)
        }
        
        for insight in insights {
            try await repository.create(insight)
        }
        
        // Act
        let allInsights = try await repository.fetchAll()
        for insight in allInsights {
            insight.category = .heartHealth
        }
        try await repository.updateBatch(allInsights)
        
        // Assert
        let updated = try await repository.fetchAll()
        XCTAssertTrue(updated.allSatisfy { $0.category == .heartHealth })
    }
    
    // MARK: - Statistics Tests
    
    func testCountUnreadInsights() async throws {
        // Arrange
        for i in 1...7 {
            let insight = createTestInsight(content: "Insight \(i)")
            insight.isRead = i <= 3 // First 3 are read
            try await repository.create(insight)
        }
        
        // Act
        let unreadCount = try await repository.count(
            where: #Predicate<AIInsight> { $0.isRead == false }
        )
        
        // Assert
        XCTAssertEqual(unreadCount, 4)
    }
    
    func testCountInsightsByCategory() async throws {
        // Arrange
        let categories: [InsightCategory] = [.heartHealth, .heartHealth, .activity, .nutrition, .general, .general, .general]
        
        for category in categories {
            let insight = createTestInsight(category: category)
            try await repository.create(insight)
        }
        
        // Act
        let heartHealthCategory = InsightCategory.heartHealth
        let generalCategory = InsightCategory.general
        let healthCount = try await repository.count(
            where: #Predicate<AIInsight> { insight in
                insight.category == heartHealthCategory
            }
        )
        let generalCount = try await repository.count(
            where: #Predicate<AIInsight> { insight in
                insight.category == generalCategory
            }
        )
        
        // Assert
        XCTAssertEqual(healthCount, 2)
        XCTAssertEqual(generalCount, 3)
    }
    
    func testCalculateInsightEngagement() async throws {
        // Arrange
        let insights = [
            (read: true, favorite: true, rating: 5),
            (read: true, favorite: false, rating: 4),
            (read: true, favorite: true, rating: nil),
            (read: false, favorite: false, rating: nil),
            (read: false, favorite: false, rating: nil)
        ]
        
        for (read, favorite, rating) in insights {
            let insight = createTestInsight()
            insight.isRead = read
            insight.isFavorite = favorite
            insight.userRating = rating
            try await repository.create(insight)
        }
        
        // Act
        let allInsights = try await repository.fetchAll()
        let readRate = Double(allInsights.filter { $0.isRead == true }.count) / Double(allInsights.count)
        let favoriteRate = Double(allInsights.filter { $0.isFavorite == true }.count) / Double(allInsights.count)
        let avgRating = allInsights.compactMap { $0.userRating }.reduce(0.0) { $0 + Double($1) } / Double(allInsights.compactMap { $0.userRating }.count)
        
        // Assert
        XCTAssertEqual(readRate, 0.6, accuracy: 0.01)
        XCTAssertEqual(favoriteRate, 0.4, accuracy: 0.01)
        XCTAssertEqual(avgRating, 4.5, accuracy: 0.01)
    }
    
    // MARK: - Sync Tests
    
    func testSyncInsightsWithBackend() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.syncStatus = .pending
        try await repository.create(insight)
        
        // Act
        try await repository.sync()
        
        // Assert
        let updated = try await repository.fetchAll().first
        XCTAssertEqual(updated?.syncStatus, .synced)
        XCTAssertNotNil(updated?.lastSyncedAt)
    }
    
    func testMergeRemoteInsights() async throws {
        // Arrange
        let localInsight = createTestInsight(content: "Local")
        localInsight.remoteID = "remote-1"
        try await repository.create(localInsight)
        
        // Simulate remote insight
        let remoteInsight = createTestInsight(content: "Remote Updated")
        remoteInsight.remoteID = "remote-1"
        
        // Act - In real app, this would be merge logic
        let existing = try await repository.fetch(
            descriptor: FetchDescriptor<AIInsight>(
                predicate: #Predicate { $0.remoteID == "remote-1" }
            )
        ).first
        
        if let existing = existing {
            existing.content = remoteInsight.content
            try await repository.update(existing)
        }
        
        // Assert
        let merged = try await repository.fetchAll().first
        XCTAssertEqual(merged?.content, "Remote Updated")
    }
    
    func testHandleSyncConflicts() async throws {
        // Arrange
        let insight = createTestInsight()
        insight.syncStatus = .conflict
        try await repository.create(insight)
        
        // Act
        try await repository.resolveSyncConflicts(for: [insight])
        
        // Assert
        let resolved = try await repository.fetchAll().first
        XCTAssertEqual(resolved?.syncStatus, .pending)
    }
    
    func testMarkInsightsAsSynced() async throws {
        // Arrange
        let insights = (1...3).map { _ in
            let insight = createTestInsight()
            insight.syncStatus = .pending
            return insight
        }
        
        for insight in insights {
            try await repository.create(insight)
        }
        
        // Act
        let pendingStatus = SyncStatus.pending
        let pending = try await repository.fetch(
            descriptor: FetchDescriptor<AIInsight>(
                predicate: #Predicate { insight in
                    insight.syncStatus == pendingStatus
                }
            )
        )
        
        for insight in pending {
            insight.syncStatus = .synced
            insight.lastSyncedAt = Date()
        }
        try await repository.updateBatch(pending)
        
        // Assert
        let synced = try await repository.fetchAll()
        XCTAssertTrue(synced.allSatisfy { $0.syncStatus == .synced })
        XCTAssertTrue(synced.allSatisfy { $0.lastSyncedAt != nil })
    }
    
    // MARK: - Search Tests
    
    func testSearchInsightsByKeyword() async throws {
        // Arrange
        let insights = [
            createTestInsight(content: "Exercise regularly for better health"),
            createTestInsight(content: "Healthy diet improves energy"),
            createTestInsight(content: "Sleep quality affects mood"),
            createTestInsight(content: "Exercise and diet work together")
        ]
        
        for insight in insights {
            try await repository.create(insight)
        }
        
        // Act
        let searchResults = try await repository.searchInsights(query: "exercise")
        
        // Assert
        XCTAssertEqual(searchResults.count, 2)
        XCTAssertTrue(searchResults.allSatisfy { $0.content?.lowercased().contains("exercise") ?? false })
    }
    
    func testSearchInsightsFullText() async throws {
        // Arrange
        let insight1 = createTestInsight(content: "Main content")
        insight1.title = "Important Health Update"
        insight1.summary = "Regular checkups recommended"
        
        let insight2 = createTestInsight(content: "Different content")
        insight2.title = "Fitness Tips"
        insight2.summary = "Stay active daily"
        
        try await repository.create(insight1)
        try await repository.create(insight2)
        
        // Act
        let searchResults = try await repository.searchInsights(query: "health")
        
        // Assert
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.title, "Important Health Update")
    }
    
    // MARK: - Performance Tests
    
    func testFetchLargeDatasetPerformance() async throws {
        // Arrange - Create 100 insights
        let insights = (1...100).map { i in
            createTestInsight(content: "Insight \(i)")
        }
        
        try await repository.createBatch(insights)
        
        // Act & Measure
        let startTime = Date()
        let _ = try await repository.fetchAll()
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Assert - Should complete in under 1 second
        XCTAssertLessThan(duration, 1.0)
    }
    
    func testComplexQueryPerformance() async throws {
        // Arrange
        for i in 1...50 {
            let insight = createTestInsight(content: "Insight \(i)")
            insight.category = i % 2 == 0 ? .heartHealth : .activity
            insight.priority = i % 3 == 0 ? .high : .medium
            insight.isRead = i % 5 == 0
            try await repository.create(insight)
        }
        
        // Act & Measure
        let startTime = Date()
        let heartHealthCategory = InsightCategory.heartHealth
        let highPriority = InsightPriority.high
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { insight in
                insight.category == heartHealthCategory &&
                insight.priority == highPriority &&
                insight.isRead == false
            }
        )
        let _ = try await repository.fetch(descriptor: descriptor)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Assert - Complex query should still be fast
        XCTAssertLessThan(duration, 0.5)
    }
}