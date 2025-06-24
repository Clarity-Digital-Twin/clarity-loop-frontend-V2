import SwiftUI

struct InsightsListView: View {
    @Environment(\.insightsRepository) private var insightsRepository
    @Environment(\.authService) private var authService
    @State private var viewModel: InsightsListViewModel?

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Health Insights")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: ChatView()) {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let viewModel {
            InsightsContentView(viewModel: viewModel)
        } else {
            ProgressView()
                .task {
                    // Small delay to ensure environment is fully propagated
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    let userId = await authService.currentUser?.id ?? ""
                    viewModel = InsightsListViewModel(
                        insightsRepository: insightsRepository,
                        userId: userId
                    )
                }
        }
    }
}

// Separate component to handle the state-based content
struct InsightsContentView: View {
    let viewModel: InsightsListViewModel

    var body: some View {
        switch viewModel.viewState {
        case .idle:
            Color.clear.onAppear {
                Task { await viewModel.loadInsights() }
            }

        case .loading:
            ProgressView("Loading insights...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .loaded(insights):
            if insights.isEmpty {
                EmptyInsightsView()
            } else {
                InsightsScrollView(viewModel: viewModel, insights: insights)
            }

        case .error:
            ErrorView(
                message: viewModel.viewState.errorMessage ?? "An error occurred",
                systemImage: "exclamationmark.triangle",
                retryAction: {
                    Task { await viewModel.loadInsights() }
                }
            )

        case .empty:
            EmptyInsightsView()
        }
    }
}

// Separate scrollable content
struct InsightsScrollView: View {
    let viewModel: InsightsListViewModel
    let insights: [InsightPreviewDTO]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Featured "Insight of the Day" card
                if let featured = insights.first {
                    FeaturedInsightCard(insight: featured)
                        .padding(.horizontal)
                }

                // Rest of the insights
                ForEach(insights.dropFirst()) { insight in
                    InsightHistoryCard(insight: insight)
                        .padding(.horizontal)
                        .onAppear {
                            // Load more when reaching the end
                            if insight.id == insights.last?.id {
                                Task { await viewModel.loadMoreInsights() }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Subviews

struct FeaturedInsightCard: View {
    let insight: InsightPreviewDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Insight of the Day", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.orange)

                Spacer()

                Text(insight.generatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(insight.narrative)
                .font(.body)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("\(insight.keyInsightsCount) insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(insight.recommendationsCount) actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ConfidenceIndicator(score: insight.confidenceScore)
            }

            NavigationLink(destination: InsightDetailView(insightId: insight.id)) {
                Text("Read More")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct InsightHistoryCard: View {
    let insight: InsightPreviewDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.generatedAt, format: .dateTime.day().month())
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                ConfidenceIndicator(score: insight.confidenceScore, size: .small)
            }

            Text(insight.narrative)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)

            HStack {
                HStack(spacing: 12) {
                    Label("\(insight.keyInsightsCount)", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(insight.recommendationsCount)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink(destination: InsightDetailView(insightId: insight.id)) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct ConfidenceIndicator: View {
    let score: Double
    var size: Size = .regular

    enum Size {
        case small, regular

        var circleSize: CGFloat {
            switch self {
            case .small: 8
            case .regular: 10
            }
        }

        var font: Font {
            switch self {
            case .small: .caption2
            case .regular: .caption
            }
        }
    }

    var color: Color {
        switch score {
        case 0.8...1.0: .green
        case 0.6..<0.8: .orange
        default: .red
        }
    }

    var label: String {
        switch score {
        case 0.8...1.0: "High"
        case 0.6..<0.8: "Medium"
        default: "Low"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: size.circleSize, height: size.circleSize)

            Text("\(label) confidence")
                .font(size.font)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Start tracking your health data to receive personalized AI-powered insights.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink(destination: ChatView()) {
                Label("Start Chat", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Placeholder for detail view
struct InsightDetailView: View {
    let insightId: String

    var body: some View {
        Text("Insight Detail: \(insightId)")
            .navigationTitle("Insight Details")
    }
}

#Preview {
    guard
        let previewAPIClient = APIClient(
            baseURLString: AppConfig.previewAPIBaseURL,
            tokenProvider: { nil }
        ) else {
        return Text("Failed to create preview client")
    }

    return InsightsListView()
        .environment(\.authService, AuthService(apiClient: previewAPIClient))
        .environment(\.insightsRepository, RemoteInsightsRepository(apiClient: previewAPIClient))
}
