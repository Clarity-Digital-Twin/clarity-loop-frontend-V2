import SwiftUI

struct DataManagementView: View {
    @Environment(\.healthDataRepository) private var healthDataRepository
    @Environment(\.insightsRepository) private var insightsRepository
    @Environment(\.healthKitService) private var healthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DataManagementViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                DataManagementContentView(viewModel: viewModel)
            } else {
                ProgressView("Loading data management...")
                    .onAppear {
                        viewModel = DataManagementViewModel(
                            healthDataRepository: healthDataRepository,
                            insightsRepository: insightsRepository,
                            healthKitService: healthKitService
                        )
                    }
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DataManagementContentView: View {
    @Bindable var viewModel: DataManagementViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Data Overview Section
                dataOverviewSection

                // Export Section
                exportSection

                // Sync Section
                syncSection

                // Deletion Section
                deletionSection
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshDataOverview()
        }
        .alert("Delete Data", isPresented: $viewModel.showingDeleteConfirmation) {
            deleteConfirmationAlert
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
            }
        }
    }

    // MARK: - Data Overview Section

    private var dataOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Data Overview", icon: "chart.bar.fill")

            if viewModel.isLoading {
                ProgressView("Loading overview...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 16) {
                    DataOverviewCard(
                        title: "Health Metrics",
                        value: "\(viewModel.totalHealthMetrics)",
                        icon: "heart.fill",
                        color: .red
                    )

                    DataOverviewCard(
                        title: "AI Insights",
                        value: "\(viewModel.totalInsights)",
                        icon: "brain.head.profile",
                        color: .purple
                    )

                    DataOverviewCard(
                        title: "Storage Used",
                        value: viewModel.dataStorageSize,
                        icon: "internaldrive.fill",
                        color: .blue
                    )

                    DataOverviewCard(
                        title: "Last Sync",
                        value: viewModel.formattedLastSync,
                        icon: "arrow.clockwise",
                        color: .green
                    )
                }

                if viewModel.hasData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Range")
                            .font(.headline)
                        Text(viewModel.dataDateRange)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Export Data", icon: "square.and.arrow.up.fill")

            if viewModel.isExporting {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.exportProgress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text(viewModel.exportStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ExportButton(
                        title: "Export All Data",
                        description: "Health metrics, insights, and settings",
                        icon: "doc.fill",
                        action: {
                            Task {
                                await viewModel.exportAllData()
                            }
                        }
                    )

                    ExportButton(
                        title: "Export Health Data Only",
                        description: "Steps, heart rate, sleep, etc.",
                        icon: "heart.fill",
                        action: {
                            Task {
                                await viewModel.exportHealthDataOnly()
                            }
                        }
                    )

                    ExportButton(
                        title: "Export Insights Only",
                        description: "AI-generated insights and recommendations",
                        icon: "brain.head.profile",
                        action: {
                            Task {
                                await viewModel.exportInsightsOnly()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Data Sync", icon: "arrow.clockwise")

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Auto-Sync")
                            .font(.headline)
                        Text("Automatically sync with HealthKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: .init(
                        get: { viewModel.autoSyncEnabled },
                        set: { _ in viewModel.toggleAutoSync() }
                    ))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if viewModel.isSyncing {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())

                        Text("Syncing with HealthKit...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.syncWithHealthKit()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                HStack {
                    Text("Last sync status:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.lastSyncStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(
                            viewModel.lastSyncStatus == "Completed" ? .green :
                                viewModel.lastSyncStatus == "Failed" ? .red : .secondary
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Deletion Section

    private var deletionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Delete Data", icon: "trash.fill")

            if viewModel.isDeletingData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Deleting data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(DeletionType.allCases, id: \.self) { type in
                        DeletionButton(
                            type: type,
                            action: {
                                viewModel.showDeleteConfirmation(for: type)
                            }
                        )
                    }
                }
            }

            Text("⚠️ Deletion is permanent and cannot be undone. Consider exporting your data first.")
                .font(.caption)
                .foregroundColor(.orange)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }
    }

    // MARK: - Delete Confirmation Alert

    private var deleteConfirmationAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {
                viewModel.showingDeleteConfirmation = false
            }

            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteData(type: viewModel.deletionType)
                }
                viewModel.showingDeleteConfirmation = false
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
}

struct DataOverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ExportButton: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DeletionButton: View {
    let type: DeletionType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.title3)
                    .foregroundColor(type.isDestructive ? .red : .orange)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    DataManagementView()
}
