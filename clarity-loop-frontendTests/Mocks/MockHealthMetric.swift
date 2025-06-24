import Foundation
@testable import clarity_loop_frontend

// Mock implementation of a health metric for testing
final class MockHealthMetric {
    let localID: UUID
    var remoteID: String?
    var timestamp: Date
    var value: Double
    var type: HealthMetricType
    var unit: String
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var syncError: String?
    var source: String
    var metadata: [String: String]?
    
    init(
        localID: UUID = UUID(),
        remoteID: String? = nil,
        timestamp: Date = Date(),
        value: Double,
        type: HealthMetricType,
        unit: String,
        syncStatus: SyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        syncError: String? = nil,
        source: String = "Test",
        metadata: [String: String]? = nil
    ) {
        self.localID = localID
        self.remoteID = remoteID
        self.timestamp = timestamp
        self.value = value
        self.type = type
        self.unit = unit
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.syncError = syncError
        self.source = source
        self.metadata = metadata
    }
    
    // Helper to create a real HealthMetric if needed
    func toHealthMetric() -> HealthMetric {
        HealthMetric(
            localID: localID,
            remoteID: remoteID,
            timestamp: timestamp,
            value: value,
            type: type,
            unit: unit,
            syncStatus: syncStatus,
            lastSyncedAt: lastSyncedAt,
            syncError: syncError,
            source: source,
            metadata: metadata,
            userProfile: nil
        )
    }
}

// Extension to make testing easier
extension HealthMetric {
    static func mock(
        timestamp: Date = Date(),
        value: Double,
        type: HealthMetricType,
        unit: String,
        syncStatus: SyncStatus = .pending
    ) -> HealthMetric {
        HealthMetric(
            timestamp: timestamp,
            value: value,
            type: type,
            unit: unit,
            syncStatus: syncStatus,
            source: "Test"
        )
    }
}