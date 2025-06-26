//
//  DashboardView.swift
//  clarity-loop-frontend-v2
//
//  Main dashboard showing health metrics
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    // @EnvironmentObject private var appState: AppState // TODO: Uncomment when needed
    
    let user: User
    
    public init(user: User) {
        self.user = user
        
        let container = DIContainer.shared
        let factory = container.require(DashboardViewModelFactory.self)
        let vm = factory.create(user)
        
        self._viewModel = State(wrappedValue: vm)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back,")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Quick Stats
                    if case .success = viewModel.metricsState {
                        QuickStatsView(viewModel: viewModel)
                    }
                    
                    // Metric Type Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: "All",
                                isSelected: viewModel.selectedMetricType == nil,
                                action: { viewModel.selectedMetricType = nil }
                            )
                            
                            ForEach(commonMetricTypes, id: \.self) { type in
                                FilterChip(
                                    title: type.displayName,
                                    isSelected: viewModel.selectedMetricType == type,
                                    action: { viewModel.selectedMetricType = type }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Metrics List
                    MetricsListView(viewModel: viewModel)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await viewModel.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadRecentMetrics()
        }
    }
    
    private var commonMetricTypes: [HealthMetricType] {
        [.heartRate, .steps, .bloodPressureSystolic, .bloodGlucose, .weight]
    }
}

// MARK: - Quick Stats View

struct QuickStatsView: View {
    let viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if let heartRateSummary = viewModel.summaryForType(.heartRate) {
                    QuickStatCard(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        value: "\(Int(heartRateSummary.latest))",
                        unit: "BPM",
                        color: .red
                    )
                }
                
                if let stepsSummary = viewModel.summaryForType(.steps) {
                    QuickStatCard(
                        icon: "figure.walk",
                        title: "Steps",
                        value: "\(Int(stepsSummary.latest))",
                        unit: "steps",
                        color: .green
                    )
                }
                
                if let weightSummary = viewModel.summaryForType(.weight) {
                    QuickStatCard(
                        icon: "scalemass.fill",
                        title: "Weight",
                        value: String(format: "%.1f", weightSummary.latest),
                        unit: "kg",
                        color: .blue
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 150)
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                #if os(iOS)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                #else
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                #endif
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Metrics List View

struct MetricsListView: View {
    let viewModel: DashboardViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.metricsState {
            case .idle:
                EmptyView()
                
            case .loading:
                ProgressView("Loading metrics...")
                    .frame(height: 200)
                
            case .success:
                if viewModel.filteredMetrics.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No metrics found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                } else {
                    ForEach(viewModel.filteredMetrics) { metric in
                        MetricRow(metric: metric)
                    }
                }
                
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let metric: HealthMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.type.displayName)
                    .font(.headline)
                
                Text(formatDate(metric.recordedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatValue(metric.value, type: metric.type))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(metric.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatValue(_ value: Double, type: HealthMetricType) -> String {
        switch type {
        case .steps, .heartRate, .bloodPressureSystolic, .bloodPressureDiastolic:
            return "\(Int(value))"
        case .weight, .height, .bodyTemperature, .bloodGlucose:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.2f", value)
        }
    }
}