@testable import clarity_loop_frontend
import Foundation
import SwiftData

/// Mock implementation of HealthRepository for testing
/// This mock bypasses SwiftData and provides controllable test behavior
class MockHealthRepository: ObservableBaseRepository<HealthMetric>, HealthRepositoryProtocol {
    // MARK: - Mock State
    var shouldFail = false
    var mockError: Error = NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    var mockMetrics: [HealthMetric] = []
    var createCalled = false
    var createBatchCalled = false
    var updateCalled = false
    var deleteCalled = false
    var fetchMetricsCalled = false
    var syncCalled = false
    
    // MARK: - Mock Behavior Controls
    var fetchMetricsDelay: TimeInterval = 0
    var syncDelay: TimeInterval = 0
    var shouldReturnEmpty = false
    
    // MARK: - Captured Parameters
    var capturedCreateMetric: HealthMetric?
    var capturedCreateBatchMetrics: [HealthMetric]?
    var capturedFetchType: HealthMetricType?
    var capturedFetchSince: Date?
    var capturedDeleteMetric: HealthMetric?
    
    // MARK: - Initialization
    
    override init(modelContext: ModelContext) {
        super.init(modelContext: modelContext)
    }
    
    // MARK: - BaseRepository Override Methods
    
    func create(_ metric: HealthMetric) async throws {
        createCalled = true
        capturedCreateMetric = metric
        
        if shouldFail {
            throw mockError
        }
        
        mockMetrics.append(metric)
    }
    
    func createBatch(_ metrics: [HealthMetric]) async throws {
        createBatchCalled = true
        capturedCreateBatchMetrics = metrics
        
        if shouldFail {
            throw mockError
        }
        
        mockMetrics.append(contentsOf: metrics)
    }
    
    func update(_ metric: HealthMetric) async throws {
        updateCalled = true
        
        if shouldFail {
            throw mockError
        }
        
        // Update the metric in our mock storage
        if let index = mockMetrics.firstIndex(where: { $0.localID == metric.localID }) {
            mockMetrics[index] = metric
        }
    }
    
    func delete(_ metric: HealthMetric) async throws {
        deleteCalled = true
        capturedDeleteMetric = metric
        
        if shouldFail {
            throw mockError
        }
        
        mockMetrics.removeAll { $0.localID == metric.localID }
    }
    
    override func syncBatch(_ models: [HealthMetric]) async throws {
        if shouldFail {
            throw mockError
        }
        
        for metric in models {
            metric.syncStatus = .synced
            // metric.lastSyncTimestamp = Date() // Not available in model
        }
    }
    
    override func resolveSyncConflicts(for models: [HealthMetric]) async throws {
        if shouldFail {
            throw mockError
        }
        // Mock implementation - just mark as resolved
    }
    
    func fetchAll() async throws -> [HealthMetric] {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics
    }
    
    override func read(by id: PersistentIdentifier) async throws -> HealthMetric? {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics.first { $0.persistentModelID == id }
    }
    
    // MARK: - HealthRepositoryProtocol Methods
    
    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric] {
        fetchMetricsCalled = true
        capturedFetchType = type
        capturedFetchSince = date
        
        // Simulate async delay if needed
        if fetchMetricsDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchMetricsDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw mockError
        }
        
        if shouldReturnEmpty {
            return []
        }
        
        // Filter mock metrics by type and date
        return mockMetrics.filter { metric in
            metric.type == type && (metric.timestamp ?? Date()) >= date
        }
    }
    
    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric? {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics
            .filter { $0.type == type }
            .sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
            .first
    }
    
    func fetchMetricsByDateRange(
        type: HealthMetricType,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics.filter { metric in
            guard let timestamp = metric.timestamp else { return false }
            return metric.type == type && timestamp >= startDate && timestamp <= endDate
        }
    }
    
    func fetchPendingSyncMetrics(limit: Int) async throws -> [HealthMetric] {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics.filter { metric in
            metric.syncStatus == .pending || metric.syncStatus == .failed
        }.prefix(limit).map { $0 }
    }
    
    func fetchMetricsNeedingSync() async throws -> [HealthMetric] {
        if shouldFail {
            throw mockError
        }
        
        return mockMetrics.filter { metric in
            metric.syncStatus == .pending || metric.syncStatus == .failed
        }
    }
    
    func batchUpload(metrics: [HealthMetric]) async throws {
        if shouldFail {
            throw mockError
        }
        
        mockMetrics.append(contentsOf: metrics)
    }
    
    override func sync() async throws {
        syncCalled = true
        
        // Simulate async delay if needed
        if syncDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(syncDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw mockError
        }
        
        // Mark all metrics as synced
        for metric in mockMetrics {
            metric.syncStatus = .synced
            // metric.lastSyncTimestamp = Date() // Not available in model
        }
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        shouldFail = false
        mockMetrics = []
        createCalled = false
        createBatchCalled = false
        updateCalled = false
        deleteCalled = false
        fetchMetricsCalled = false
        syncCalled = false
        fetchMetricsDelay = 0
        syncDelay = 0
        shouldReturnEmpty = false
        
        capturedCreateMetric = nil
        capturedCreateBatchMetrics = nil
        capturedFetchType = nil
        capturedFetchSince = nil
        capturedDeleteMetric = nil
    }
    
    func addMockMetric(type: HealthMetricType, value: Double, date: Date = Date()) {
        let metric = HealthMetric(
            timestamp: date,
            value: value,
            type: type,
            unit: type.unit
        )
        metric.source = "Mock"
        mockMetrics.append(metric)
    }
    
    func setupMockData(days: Int = 7) {
        let calendar = Calendar.current
        let now = Date()
        
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                // Add steps
                addMockMetric(type: .steps, value: Double.random(in: 5000...15000), date: date)
                
                // Add heart rate
                addMockMetric(type: .heartRate, value: Double.random(in: 60...80), date: date)
                
                // Add sleep
                addMockMetric(type: .sleepDuration, value: Double.random(in: 6...9), date: date)
            }
        }
    }
}

// MARK: - HealthMetricType Extension for Testing
extension HealthMetricType {
    var unit: String {
        switch self {
        case .steps:
            return "steps"
        case .heartRate, .heartRateVariability:
            return "bpm"
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepLight, .sleepAwake:
            return "hours"
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return "mmHg"
        case .activeEnergy, .restingEnergy:
            return "kcal"
        case .exerciseMinutes:
            return "minutes"
        case .standHours:
            return "hours"
        case .respiratoryRate:
            return "breaths/min"
        case .bodyTemperature:
            return "°C"
        case .oxygenSaturation:
            return "%"
        case .weight:
            return "kg"
        case .height:
            return "cm"
        case .bodyMassIndex:
            return "kg/m²"
        }
    }
}