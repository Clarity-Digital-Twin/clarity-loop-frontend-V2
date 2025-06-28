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
    @Environment(AppState.self) private var appState
    @State private var showingAddMetric = false
    
    public init() {
        let container = DIContainer.shared
        let factory = container.require(DashboardViewModelFactory.self)
        // TODO: Pass user ID when factory is updated
        let vm = factory.create(User(id: UUID(), email: "temp@example.com", firstName: "Temp", lastName: "User"))
        
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
                        
                        Text(appState.currentUserName ?? "User")
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
                ToolbarItem(placement: .primaryAction) {
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
        .sheet(isPresented: $showingAddMetric) {
            HealthMetricsView()
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating Action Button
            Button(action: { showingAddMetric = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4, x: 2, y: 2)
            }
            .padding()
            .accessibilityLabel("Add new health metric")
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
                
            case .empty:
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No health data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                
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
                        MetricRow(
                            metric: metric,
                            previousValue: viewModel.previousValueFor(metric)
                        )
                    }
                }
                
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text(message.localizedDescription)
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
    let previousValue: Double?
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Metric Icon
                Image(systemName: iconForMetricType(metric.type))
                    .font(.title2)
                    .foregroundColor(colorForMetricType(metric.type))
                    .frame(width: 40, height: 40)
                    .background(colorForMetricType(metric.type).opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.type.displayName)
                        .font(.headline)
                    
                    Text(formatDate(metric.recordedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(formatValue(metric.value, type: metric.type))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(metric.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Trend indicator
                    if let previous = previousValue {
                        TrendIndicator(current: metric.value, previous: previous)
                    }
                }
            }
            .padding()
            
            // Expandable notes section
            if let notes = metric.notes, !notes.isEmpty {
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(notes)
                            .font(.footnote)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
        .onTapGesture {
            if metric.notes != nil {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
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
    
    private func iconForMetricType(_ type: HealthMetricType) -> String {
        switch type {
        case .heartRate: return "heart.fill"
        case .steps: return "figure.walk"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "waveform.path.ecg"
        case .bloodGlucose: return "drop.fill"
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        case .bodyTemperature: return "thermometer"
        case .oxygenSaturation: return "lungs.fill"
        case .respiratoryRate: return "wind"
        case .sleepDuration: return "bed.double.fill"
        case .caloriesBurned: return "flame.fill"
        case .waterIntake: return "drop.triangle.fill"
        case .exerciseDuration: return "figure.run"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func colorForMetricType(_ type: HealthMetricType) -> Color {
        switch type {
        case .heartRate: return .red
        case .steps: return .green
        case .bloodPressureSystolic, .bloodPressureDiastolic: return .purple
        case .bloodGlucose: return .orange
        case .weight: return .blue
        case .height: return .indigo
        case .bodyTemperature: return .pink
        case .oxygenSaturation: return .cyan
        case .respiratoryRate: return .teal
        case .sleepDuration: return .indigo
        case .caloriesBurned: return .orange
        case .waterIntake: return .blue
        case .exerciseDuration: return .green
        default: return .gray
        }
    }
}

// MARK: - Trend Indicator

struct TrendIndicator: View {
    let current: Double
    let previous: Double
    
    private var trend: Trend {
        if current > previous {
            return .up
        } else if current < previous {
            return .down
        } else {
            return .stable
        }
    }
    
    private var percentageChange: Double {
        guard previous != 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
                .foregroundColor(trend.color)
            
            Text(String(format: "%.1f%%", abs(percentageChange)))
                .font(.caption)
                .foregroundColor(trend.color)
        }
    }
    
    enum Trend {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
}