import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var animateIcon = false

    init(
        title: String,
        message: String,
        systemImage: String = "tray.fill",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animateIcon ? 1.0 : 0.9)
                    
                    Image(systemName: systemImage)
                        .font(.system(size: 56))
                        .foregroundColor(iconColor)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(animateIcon ? 1.0 : 0.8)
                }
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                        .repeatForever(autoreverses: true),
                    value: animateIcon
                )
                .onAppear {
                    animateIcon = true
                }

                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    Text(message)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                .padding(.horizontal)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "arrow.right")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var iconColor: Color {
        switch systemImage {
        case let icon where icon.contains("heart"):
            return .red
        case let icon where icon.contains("lightbulb"):
            return .yellow
        case let icon where icon.contains("message"):
            return .blue
        case let icon where icon.contains("chart"):
            return .green
        case let icon where icon.contains("magnifying"):
            return .purple
        default:
            return .accentColor
        }
    }
    
    private var iconBackgroundColor: Color {
        iconColor
    }
}

// MARK: - Specialized Empty State Views

struct NoHealthDataView: View {
    let onSetupHealthKit: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Track Your Health Journey",
            message: "Connect HealthKit to start monitoring your sleep, activity, and wellness patterns. Get personalized insights to optimize your health.",
            systemImage: "heart.text.square.fill",
            actionTitle: "Connect HealthKit",
            action: onSetupHealthKit
        )
    }
}

struct NoInsightsView: View {
    let onGenerateInsight: (() -> Void)?

    init(onGenerateInsight: (() -> Void)? = nil) {
        self.onGenerateInsight = onGenerateInsight
    }

    var body: some View {
        EmptyStateView(
            title: "Discover Your Patterns",
            message: "Sync your health data to unlock AI-powered insights about your sleep quality, activity levels, and wellness trends.",
            systemImage: "lightbulb.max.fill",
            actionTitle: onGenerateInsight != nil ? "Generate First Insight" : nil,
            action: onGenerateInsight
        )
    }
}

struct NoSearchResultsView: View {
    let searchTerm: String
    let onClearSearch: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Results Found",
            message: "We couldn't find anything matching '\(searchTerm)'. Try different keywords or clear the search.",
            systemImage: "magnifyingglass",
            actionTitle: "Clear Search",
            action: onClearSearch
        )
    }
}

struct NoConversationView: View {
    let onStartChat: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Your Health Assistant Awaits",
            message: "Ask questions about your health data, explore trends, or get personalized wellness recommendations. I'm here to help!",
            systemImage: "bubble.left.and.bubble.right.fill",
            actionTitle: "Start Your First Chat",
            action: onStartChat
        )
    }
}

struct NoAnalysisHistoryView: View {
    let onRunAnalysis: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No Analysis History",
            message: "Run your first PAT analysis to see detailed insights about your sleep and activity patterns.",
            systemImage: "chart.bar.fill",
            actionTitle: "Run Analysis",
            action: onRunAnalysis
        )
    }
}

struct MaintenanceModeView: View {
    let estimatedDowntime: String?

    var body: some View {
        EmptyStateView(
            title: "Under Maintenance",
            message: estimatedDowntime.map { "We're improving our services. Expected completion: \($0)" }
                ?? "We're performing scheduled maintenance. Please check back soon.",
            systemImage: "wrench.and.screwdriver.fill"
        )
    }
}

struct FeatureUnavailableView: View {
    let featureName: String
    let reason: String

    var body: some View {
        EmptyStateView(
            title: "\(featureName) Unavailable",
            message: reason,
            systemImage: "exclamationmark.triangle.fill"
        )
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}


// MARK: - Preview

#Preview("Empty Health Data") {
    NoHealthDataView(onSetupHealthKit: {})
}

#Preview("No Insights") {
    NoInsightsView(onGenerateInsight: {})
}

#Preview("Loading State") {
    LoadingStateView(message: "Analyzing your health data...")
}

#Preview("Maintenance Mode") {
    MaintenanceModeView(estimatedDowntime: "2 hours")
}
