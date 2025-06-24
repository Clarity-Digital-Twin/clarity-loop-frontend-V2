import SwiftUI

struct SyncStatusView: View {
    let syncManager: HealthDataSyncManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .symbolEffect(.pulse, value: syncManager.isSyncing)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Data Sync")
                        .font(.headline)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if syncManager.isSyncing {
                    CircularProgressView(progress: syncManager.syncProgress)
                        .frame(width: 40, height: 40)
                } else if let lastSync = syncManager.lastSyncDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last sync")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if syncManager.isSyncing {
                ProgressView(value: syncManager.syncProgress) {
                    Text(progressText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }
            
            if let error = syncManager.syncError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Button("Retry") {
                        Task {
                            await syncManager.syncHealthData()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var iconColor: Color {
        if syncManager.syncError != nil {
            return .orange
        } else if syncManager.isSyncing {
            return .blue
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if syncManager.isSyncing {
            return "Syncing your health data..."
        } else if syncManager.syncError != nil {
            return "Sync failed"
        } else if syncManager.lastSyncDate != nil {
            return "All data synced"
        } else {
            return "Ready to sync"
        }
    }
    
    private var progressText: String {
        let percentage = Int(syncManager.syncProgress * 100)
        
        if syncManager.syncProgress < 0.3 {
            return "Preparing data... \(percentage)%"
        } else if syncManager.syncProgress < 0.6 {
            return "Fetching health data... \(percentage)%"
        } else if syncManager.syncProgress < 1.0 {
            return "Uploading to server... \(percentage)%"
        } else {
            return "Sync complete!"
        }
    }
}

// MARK: - Sync Progress Card

struct SyncProgressCard: View {
    let syncManager: HealthDataSyncManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Syncing Health Data")
                        .font(.headline)
                    
                    Text(progressDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(lineWidth: 4)
                        .opacity(0.3)
                        .foregroundColor(.blue)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(syncManager.syncProgress, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear, value: syncManager.syncProgress)
                    
                    Text("\(Int(syncManager.syncProgress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .frame(width: 50, height: 50)
            }
            
            ProgressView(value: syncManager.syncProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack(spacing: 20) {
                StepIndicator(
                    title: "Prepare",
                    isActive: syncManager.syncProgress >= 0,
                    isComplete: syncManager.syncProgress >= 0.3
                )
                
                StepIndicator(
                    title: "Fetch",
                    isActive: syncManager.syncProgress >= 0.3,
                    isComplete: syncManager.syncProgress >= 0.6
                )
                
                StepIndicator(
                    title: "Upload",
                    isActive: syncManager.syncProgress >= 0.6,
                    isComplete: syncManager.syncProgress >= 1.0
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var progressDescription: String {
        if syncManager.syncProgress < 0.3 {
            return "Preparing your health data for sync..."
        } else if syncManager.syncProgress < 0.6 {
            return "Fetching recent health metrics..."
        } else if syncManager.syncProgress < 1.0 {
            return "Uploading data to secure servers..."
        } else {
            return "Sync completed successfully!"
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let title: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 24, height: 24)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(textColor)
        }
    }
    
    private var backgroundColor: Color {
        if isComplete {
            return .green
        } else if isActive {
            return .blue
        } else {
            return Color(.systemGray4)
        }
    }
    
    private var textColor: Color {
        if isComplete || isActive {
            return .primary
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Sync Status - Idle") {
    Text("Preview unavailable - Mock services not available in this target")
        .padding()
}

#Preview("Sync Status - Progress") {
    Text("Preview unavailable - Mock services not available in this target")
        .padding()
}

#Preview("Sync Progress Card") {
    Text("Preview unavailable - Mock services not available in this target")
        .padding()
}
#endif

