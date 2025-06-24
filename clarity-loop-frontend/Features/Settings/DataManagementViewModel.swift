import Foundation
import Observation

@Observable
final class DataManagementViewModel {
    // MARK: - Dependencies

    private let healthDataRepository: any HealthDataRepositoryProtocol
    private let insightsRepository: any InsightsRepositoryProtocol
    private let healthKitService: any HealthKitServiceProtocol

    // MARK: - State Properties

    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // Data overview
    var totalHealthMetrics = 0
    var totalInsights = 0
    var lastSyncDate: Date?
    var dataStorageSize = "0 MB"
    var oldestDataDate: Date?
    var newestDataDate: Date?

    // Export state
    var isExporting = false
    var exportProgress = 0.0
    var exportStatus = "Ready to export"

    // Deletion state
    var showingDeleteConfirmation = false
    var deletionType: DeletionType = .allData
    var isDeletingData = false

    // Sync state
    var isSyncing = false
    var syncProgress = 0.0
    var autoSyncEnabled = true
    var lastSyncStatus = "Unknown"

    // MARK: - Computed Properties

    var hasData: Bool {
        totalHealthMetrics > 0 || totalInsights > 0
    }

    var formattedLastSync: String {
        guard let lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: lastSyncDate, relativeTo: Date())
    }

    var dataDateRange: String {
        guard let oldest = oldestDataDate, let newest = newestDataDate else {
            return "No data available"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if Calendar.current.isDate(oldest, inSameDayAs: newest) {
            return formatter.string(from: newest)
        } else {
            return "\(formatter.string(from: oldest)) - \(formatter.string(from: newest))"
        }
    }

    // MARK: - Initializer

    init(
        healthDataRepository: any HealthDataRepositoryProtocol,
        insightsRepository: any InsightsRepositoryProtocol,
        healthKitService: any HealthKitServiceProtocol
    ) {
        self.healthDataRepository = healthDataRepository
        self.insightsRepository = insightsRepository
        self.healthKitService = healthKitService
        loadDataOverview()
    }

    // MARK: - Data Overview

    func loadDataOverview() {
        Task {
            await refreshDataOverview()
        }
    }

    func refreshDataOverview() async {
        isLoading = true
        errorMessage = nil

        do {
            // Simulate loading data overview
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // In a real app, you'd fetch actual data counts and metadata
            totalHealthMetrics = Int.random(in: 100...1000)
            totalInsights = Int.random(in: 10...50)
            dataStorageSize = "\(Int.random(in: 5...50)) MB"

            // Set some sample dates
            let calendar = Calendar.current
            oldestDataDate = calendar.date(byAdding: .day, value: -30, to: Date())
            newestDataDate = Date()
            lastSyncDate = calendar.date(byAdding: .hour, value: -2, to: Date())
            lastSyncStatus = "Completed"

        } catch {
            errorMessage = "Failed to load data overview: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Data Export

    func exportAllData() async {
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Preparing export..."
        errorMessage = nil

        do {
            // Simulate export process with progress updates
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                exportProgress = Double(i) / 10.0

                switch i {
                case 1...3:
                    exportStatus = "Collecting health data..."
                case 4...6:
                    exportStatus = "Collecting insights..."
                case 7...8:
                    exportStatus = "Generating export file..."
                case 9...10:
                    exportStatus = "Finalizing export..."
                default:
                    break
                }
            }

            exportStatus = "Export completed"
            successMessage = "Your data has been exported successfully. Check your email for the download link."

        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            exportStatus = "Export failed"
        }

        isExporting = false
    }

    func exportHealthDataOnly() async {
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Exporting health data..."
        errorMessage = nil

        do {
            // Simulate health data export
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                exportProgress = Double(i) / 5.0
            }

            exportStatus = "Health data export completed"
            successMessage = "Your health data has been exported successfully."

        } catch {
            errorMessage = "Health data export failed: \(error.localizedDescription)"
            exportStatus = "Export failed"
        }

        isExporting = false
    }

    func exportInsightsOnly() async {
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Exporting insights..."
        errorMessage = nil

        do {
            // Simulate insights export
            for i in 1...3 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                exportProgress = Double(i) / 3.0
            }

            exportStatus = "Insights export completed"
            successMessage = "Your insights have been exported successfully."

        } catch {
            errorMessage = "Insights export failed: \(error.localizedDescription)"
            exportStatus = "Export failed"
        }

        isExporting = false
    }

    // MARK: - Data Deletion

    func deleteData(type: DeletionType) async {
        isDeletingData = true
        errorMessage = nil

        do {
            switch type {
            case .allData:
                try await deleteAllData()
            case .healthDataOnly:
                try await deleteHealthDataOnly()
            case .insightsOnly:
                try await deleteInsightsOnly()
            case .oldData:
                try await deleteOldData()
            }

            successMessage = "Data deleted successfully"
            await refreshDataOverview()

        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
        }

        isDeletingData = false
    }

    private func deleteAllData() async throws {
        // Simulate deletion process
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // In a real app, you'd call your backend and local storage deletion methods
        totalHealthMetrics = 0
        totalInsights = 0
        dataStorageSize = "0 MB"
        oldestDataDate = nil
        newestDataDate = nil
    }

    private func deleteHealthDataOnly() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        totalHealthMetrics = 0
        dataStorageSize = "\(Int.random(in: 1...10)) MB"
    }

    private func deleteInsightsOnly() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        totalInsights = 0
    }

    private func deleteOldData() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Simulate deleting old data (older than 30 days)
        totalHealthMetrics = max(0, totalHealthMetrics - Int.random(in: 50...200))
        totalInsights = max(0, totalInsights - Int.random(in: 5...15))

        // Update oldest date
        oldestDataDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
    }

    // MARK: - Data Sync

    func syncWithHealthKit() async {
        isSyncing = true
        syncProgress = 0.0
        errorMessage = nil
        lastSyncStatus = "In progress"

        do {
            // Simulate sync process
            for i in 1...8 {
                try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
                syncProgress = Double(i) / 8.0
            }

            lastSyncDate = Date()
            lastSyncStatus = "Completed"
            successMessage = "HealthKit sync completed successfully"

            // Refresh data overview to show new data
            await refreshDataOverview()

        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            lastSyncStatus = "Failed"
        }

        isSyncing = false
    }

    func toggleAutoSync() {
        autoSyncEnabled.toggle()

        // In a real app, you'd save this preference and configure background sync
        if autoSyncEnabled {
            successMessage = "Auto-sync enabled"
        } else {
            successMessage = "Auto-sync disabled"
        }
    }

    // MARK: - Utility Methods

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func showDeleteConfirmation(for type: DeletionType) {
        deletionType = type
        showingDeleteConfirmation = true
    }
}

// MARK: - Supporting Types

enum DeletionType: CaseIterable {
    case allData
    case healthDataOnly
    case insightsOnly
    case oldData

    var title: String {
        switch self {
        case .allData:
            "All Data"
        case .healthDataOnly:
            "Health Data Only"
        case .insightsOnly:
            "Insights Only"
        case .oldData:
            "Old Data (30+ days)"
        }
    }

    var description: String {
        switch self {
        case .allData:
            "This will permanently delete all your health data and insights."
        case .healthDataOnly:
            "This will permanently delete all your health metrics but keep insights."
        case .insightsOnly:
            "This will permanently delete all your AI-generated insights but keep health data."
        case .oldData:
            "This will permanently delete data older than 30 days."
        }
    }

    var isDestructive: Bool {
        switch self {
        case .allData, .healthDataOnly, .insightsOnly:
            true
        case .oldData:
            false
        }
    }
}
