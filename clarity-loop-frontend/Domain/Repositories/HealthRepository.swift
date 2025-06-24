import Foundation
import Observation
import SwiftData

// MARK: - Health Repository Implementation

@Observable
final class HealthRepository: ObservableBaseRepository<HealthMetric>, HealthRepositoryProtocol {
    // MARK: - Properties

    private let maxBatchSize = 100
    private var syncTask: Task<Void, Error>?

    // MARK: - Query Operations

    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric] {
        // Use simpler approach to avoid predicate macro issues
        let allMetrics = try await fetchAll()
        
        let filtered = allMetrics.filter { metric in
            metric.type == type && (metric.timestamp ?? Date.distantPast) >= date
        }
        
        return filtered.sorted { 
            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) 
        }
    }

    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric? {
        let allMetrics = try await fetchAll()
        
        return allMetrics
            .filter { $0.type == type }
            .sorted { 
                ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) 
            }
            .first
    }

    func fetchMetricsByDateRange(
        type: HealthMetricType,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        let allMetrics = try await fetchAll()
        
        let filtered = allMetrics.filter { metric in
            guard let timestamp = metric.timestamp else { return false }
            return metric.type == type && 
                   timestamp >= startDate && 
                   timestamp <= endDate
        }
        
        return filtered.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
    }

    func fetchPendingSyncMetrics(limit: Int = 100) async throws -> [HealthMetric] {
        let pendingStatus = SyncStatus.pending.rawValue
        let failedStatus = SyncStatus.failed.rawValue

        let allMetrics = try await fetchAll()
        
        let filtered = allMetrics.filter { metric in
            let status = metric.syncStatus?.rawValue ?? ""
            return status == pendingStatus || status == failedStatus
        }
        
        return Array(filtered
            .sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
            .prefix(limit))
    }

    func fetchMetricsNeedingSync() async throws -> [HealthMetric] {
        // Use the same logic as fetchPendingSyncMetrics
        try await fetchPendingSyncMetrics()
    }

    // MARK: - Batch Operations

    func batchUpload(metrics: [HealthMetric]) async throws {
        // Validate batch size
        guard metrics.count <= maxBatchSize else {
            throw RepositoryError.batchOperationFailed(
                NSError(
                    domain: "HealthRepository",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Batch size exceeds maximum of \(maxBatchSize)"]
                )
            )
        }

        // Process in batches if needed
        let chunks = metrics.chunked(into: maxBatchSize)

        for chunk in chunks {
            try await createBatch(chunk)

            // Mark for sync
            for metric in chunk {
                metric.syncStatus = .pending
            }
        }

        // Trigger sync after batch upload
        try await sync()
    }

    // MARK: - Sync Operations

    override func sync() async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }

        do {
            // Get pending metrics
            let pendingMetrics = try await fetchPendingSyncMetrics()
            guard !pendingMetrics.isEmpty else {
                await updateSyncStatus(pendingCount: 0)
                return
            }

            await updateSyncStatus(pendingCount: pendingMetrics.count)

            // TODO: Implement actual API sync when BackendAPIClient has health endpoints
            // For now, simulate sync with delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Mark as synced
            for metric in pendingMetrics {
                metric.syncStatus = .synced
                metric.lastSyncedAt = Date()
                metric.syncError = nil
            }

            try modelContext.save()
            await updateSyncStatus(pendingCount: 0)

        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }

    override func syncBatch(_ models: [HealthMetric]) async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }

        do {
            // Process in chunks
            let chunks = models.chunked(into: maxBatchSize)

            for chunk in chunks {
                // TODO: Implement actual API sync
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Mark as synced
                for metric in chunk {
                    metric.syncStatus = .synced
                    metric.lastSyncedAt = Date()
                    metric.syncError = nil
                }
            }

            try modelContext.save()

        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }

    override func resolveSyncConflicts(for models: [HealthMetric]) async throws {
        // Implement last-write-wins strategy
        for metric in models {
            if metric.remoteID != nil {
                // In a real implementation, we would fetch the remote version
                // and compare timestamps to resolve conflicts

                // For now, local wins
                metric.syncStatus = .pending
                metric.syncError = nil
            }
        }

        try modelContext.save()
    }

    // MARK: - Statistics

    func calculateAverageMetric(
        type: HealthMetricType,
        since date: Date
    ) async throws -> Double? {
        let metrics = try await fetchMetrics(for: type, since: date)
        guard !metrics.isEmpty else { return nil }

        let sum = metrics.reduce(0) { $0 + ($1.value ?? 0.0) }
        return sum / Double(metrics.count)
    }

    func calculateMetricTrend(
        type: HealthMetricType,
        days: Int
    ) async throws -> TrendDirection? {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }

        let metrics = try await fetchMetricsByDateRange(
            type: type,
            startDate: startDate,
            endDate: endDate
        )

        guard metrics.count >= 2 else { return nil }

        let halfPoint = metrics.count / 2
        let firstHalf = metrics.prefix(halfPoint)
        let secondHalf = metrics.suffix(halfPoint)

        let firstAverage = firstHalf.reduce(0) { $0 + ($1.value ?? 0.0) } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0) { $0 + ($1.value ?? 0.0) } / Double(secondHalf.count)

        let changeThreshold = 0.05 // 5% change threshold
        let percentChange = abs(secondAverage - firstAverage) / firstAverage

        if percentChange < changeThreshold {
            return .stable
        } else if secondAverage > firstAverage {
            return .increasing
        } else {
            return .decreasing
        }
    }

    // MARK: - Cleanup

    deinit {
        syncTask?.cancel()
    }
}

// MARK: - Supporting Types

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

// MARK: - Array Extension for Chunking
// Note: chunked(into:) is defined in EnhancedOfflineQueueManager.swift

// MARK: - Mock Health Data Generator (for development/testing)

#if DEBUG
    extension HealthRepository {
        func generateMockData(days: Int = 7) async throws {
            let calendar = Calendar.current
            let now = Date()

            for dayOffset in 0..<days {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                // Generate heart rate data (every hour)
                for hour in 0..<24 {
                    guard
                        let timestamp = calendar
                            .date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: date)) else { continue }

                    let heartRate = HealthMetric(
                        localID: UUID(),
                        remoteID: nil,
                        timestamp: timestamp,
                        value: Double.random(in: 60...100),
                        type: .heartRate,
                        unit: "bpm",
                        syncStatus: .pending,
                        lastSyncedAt: nil,
                        syncError: nil,
                        source: "Mock",
                        metadata: ["device": "Simulator"],
                        userProfile: nil
                    )

                    try await create(heartRate)
                }

                // Generate steps data (every 30 minutes during waking hours)
                for halfHour in 12..<40 { // 6 AM to 10 PM
                    guard
                        let timestamp = calendar.date(
                            byAdding: .minute,
                            value: halfHour * 30,
                            to: calendar.startOfDay(for: date)
                        ) else { continue }

                    let steps = HealthMetric(
                        localID: UUID(),
                        remoteID: nil,
                        timestamp: timestamp,
                        value: Double.random(in: 50...500),
                        type: .steps,
                        unit: "count",
                        syncStatus: .pending,
                        lastSyncedAt: nil,
                        syncError: nil,
                        source: "Mock",
                        metadata: ["device": "Simulator"],
                        userProfile: nil
                    )

                    try await create(steps)
                }
            }
        }
    }
#endif
