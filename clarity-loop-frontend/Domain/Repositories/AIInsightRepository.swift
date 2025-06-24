import Foundation
import Observation
import SwiftData

// MARK: - AI Insight Repository Implementation

@Observable
final class AIInsightRepository: ObservableBaseRepository<AIInsight>, AIInsightRepositoryProtocol {
    // MARK: - Query Operations

    func fetchInsights(for category: InsightCategory?, limit: Int = 50) async throws -> [AIInsight] {
        var descriptor: FetchDescriptor<AIInsight>

        if let category {
            let predicate = #Predicate<AIInsight> { insight in
                insight.category == category
            }
            descriptor = FetchDescriptor<AIInsight>(predicate: predicate)
        } else {
            descriptor = FetchDescriptor<AIInsight>()
        }

        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = limit

        return try await fetch(descriptor: descriptor)
    }

    func fetchConversation(id: UUID) async throws -> [AIInsight] {
        let predicate = #Predicate<AIInsight> { insight in
            insight.conversationID == id
        }

        var descriptor = FetchDescriptor<AIInsight>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        return try await fetch(descriptor: descriptor)
    }

    func searchInsights(query: String) async throws -> [AIInsight] {
        let lowercasedQuery = query.lowercased()

        let predicate = #Predicate<AIInsight> { insight in
            (insight.content?.localizedStandardContains(lowercasedQuery) ?? false) ||
                (insight.title?.localizedStandardContains(lowercasedQuery) ?? false) ||
                (insight.summary?.localizedStandardContains(lowercasedQuery) ?? false)
        }

        var descriptor = FetchDescriptor<AIInsight>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        return try await fetch(descriptor: descriptor)
    }

    // MARK: - Conversation Management

    func createConversation(userMessage: String, category: InsightCategory = .general) async throws -> AIInsight {
        let message = AIInsight.createUserMessage(content: userMessage, category: category)
        try await create(message)
        return message
    }

    func addAssistantResponse(
        content: String,
        conversationID: UUID,
        category: InsightCategory,
        parentMessageID: UUID? = nil
    ) async throws -> AIInsight {
        let message = AIInsight.createAssistantMessage(
            content: content,
            category: category,
            conversationID: conversationID,
            parentMessageID: parentMessageID
        )
        try await create(message)
        return message
    }

    // MARK: - Sync Operations

    override func sync() async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }

        do {
            // Get pending insights
            let pendingInsights = try await fetchPendingSyncInsights()
            guard !pendingInsights.isEmpty else {
                await updateSyncStatus(pendingCount: 0)
                return
            }

            await updateSyncStatus(pendingCount: pendingInsights.count)

            // TODO: Implement actual API sync
            // For now, simulate sync
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Mark as synced
            for insight in pendingInsights {
                insight.syncStatus = .synced
                insight.lastSyncedAt = Date()
            }

            try modelContext.save()
            await updateSyncStatus(pendingCount: 0)

        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }

    override func syncBatch(_ models: [AIInsight]) async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }

        // Sync insights in batches
        for insight in models {
            // TODO: Implement actual API sync
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            insight.syncStatus = .synced
            insight.lastSyncedAt = Date()
        }

        try modelContext.save()
    }

    override func resolveSyncConflicts(for models: [AIInsight]) async throws {
        // For AI insights, keep both local and remote versions
        // User can choose which to keep
        for model in models {
            model.syncStatus = .conflict
        }
        try modelContext.save()
    }

    // MARK: - Statistics

    func fetchUnreadCount() async throws -> Int {
        let predicate = #Predicate<AIInsight> { insight in
            !(insight.isRead ?? false)
        }
        return try await count(where: predicate)
    }

    func fetchFavoriteInsights() async throws -> [AIInsight] {
        let predicate = #Predicate<AIInsight> { insight in
            insight.isFavorite ?? false
        }

        var descriptor = FetchDescriptor<AIInsight>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        return try await fetch(descriptor: descriptor)
    }

    // MARK: - Private Helpers

    private func fetchPendingSyncInsights() async throws -> [AIInsight] {
        let pendingStatus = SyncStatus.pending.rawValue
        let failedStatus = SyncStatus.failed.rawValue

        let predicate = #Predicate<AIInsight> { insight in
            (insight.syncStatus?.rawValue == pendingStatus) || (insight.syncStatus?.rawValue == failedStatus)
        }

        var descriptor = FetchDescriptor<AIInsight>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        return try await fetch(descriptor: descriptor)
    }
}
