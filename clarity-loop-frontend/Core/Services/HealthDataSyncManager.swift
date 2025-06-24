import Foundation
import BackgroundTasks
import Observation

/// Manages periodic health data synchronization with the backend
@Observable
@MainActor
final class HealthDataSyncManager {
    // MARK: - Properties
    
    private let healthKitService: HealthKitServiceProtocol
    private let authService: AuthServiceProtocol
    private let syncInterval: TimeInterval = 3600 // 1 hour
    private let backgroundTaskIdentifier = "com.clarity.healthsync"
    
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: Error?
    var syncProgress: Double = 0.0
    
    // MARK: - Initialization
    
    init(
        healthKitService: HealthKitServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.authService = authService
        
        // Register background task
        registerBackgroundTask()
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger a health data sync
    func syncHealthData() async {
        guard !isSyncing else { return }
        guard let currentUser = await authService.currentUser else {
            syncError = HealthSyncError.userNotAuthenticated
            return
        }
        
        isSyncing = true
        syncError = nil
        syncProgress = 0.0
        
        do {
            // Get last sync date or use 7 days ago
            let startDate = lastSyncDate ?? Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let endDate = Date()
            
            // Fetch health data
            syncProgress = 0.3
            let uploadRequest = try await healthKitService.fetchHealthDataForUpload(
                from: startDate,
                to: endDate,
                userId: currentUser.id
            )
            
            // Skip if no samples to upload
            if uploadRequest.samples.isEmpty {
                syncProgress = 1.0
                lastSyncDate = endDate
                isSyncing = false
                return
            }
            
            // Upload data
            syncProgress = 0.6
            let response = try await healthKitService.uploadHealthKitData(uploadRequest)
            
            if response.success {
                syncProgress = 1.0
                lastSyncDate = endDate
                
                // Schedule next sync
                scheduleNextSync()
            } else {
                throw HealthSyncError.uploadFailed(response.message ?? "Unknown error")
            }
            
        } catch {
            syncError = error
            print("❌ Health sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Enable automatic background sync
    func enableBackgroundSync() async {
        do {
            try await healthKitService.enableBackgroundDelivery()
            healthKitService.setupObserverQueries()
            scheduleNextSync()
        } catch {
            print("❌ Failed to enable background sync: \(error)")
        }
    }
    
    /// Disable automatic background sync
    func disableBackgroundSync() async {
        do {
            try await healthKitService.disableBackgroundDelivery()
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        } catch {
            print("❌ Failed to disable background sync: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    private func scheduleNextSync() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Failed to schedule background sync: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule next sync immediately
        scheduleNextSync()
        
        // Create a task to sync data
        let syncTask = Task {
            await self.syncHealthData()
        }
        
        // Set expiration handler
        task.expirationHandler = {
            syncTask.cancel()
        }
        
        // Mark task complete when sync finishes
        Task {
            await syncTask.value
            task.setTaskCompleted(success: self.syncError == nil)
        }
    }
}

// MARK: - Health Sync Errors

enum HealthSyncError: LocalizedError {
    case userNotAuthenticated
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Please log in to sync health data"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}