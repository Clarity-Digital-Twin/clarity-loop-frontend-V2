//
//  DashboardView.swift
//  clarity-loop-frontend-v2
//
//  Main dashboard showing health metrics
//

import SwiftUI
import ClarityDomain
import ClarityCore
import ClarityData

public struct DashboardView: View {
    @Environment(\.dashboardViewModelFactory) private var factory
    @Environment(\.healthMetricRepository) private var repository
    @Environment(\.apiClient) private var apiClient
    @State private var viewModel: DashboardViewModel?
    @Environment(AppState.self) private var appState
    @State private var showingAddMetric = false
    
    public init() {
        // NO WORK IN INIT - dependencies resolved in .task
    }
    
    public var body: some View {
        Group {
            if let viewModel {
                DashboardContentView(
                    viewModel: viewModel,
                    showingAddMetric: $showingAddMetric,
                    repository: repository,
                    apiClient: apiClient
                )
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Initialize viewModel from factory
            print("🔍 DashboardView.task - checking for factory...")
            
            guard let factory else {
                print("❌ DashboardViewModelFactory not provided via environment")
                print("❌ This means .withDependencies() didn't inject the factory properly")
                // Don't crash - just show loading forever
                return
            }
            
            print("✅ DashboardViewModelFactory found, creating viewModel...")
            
            // Create guest user as default
            let guestUser = User(
                id: UUID(),
                email: "guest@clarity.health",
                firstName: "Guest",
                lastName: "User"
            )
            
            viewModel = factory.create(guestUser)
            print("✅ DashboardView viewModel created successfully")
        }
    }
}

// Separate view for dashboard content
private struct DashboardContentView: View {
    @Bindable var viewModel: DashboardViewModel
    @Binding var showingAddMetric: Bool
    let repository: HealthMetricRepositoryProtocol?
    let apiClient: APIClientProtocol?
    @Environment(AppState.self) private var appState
    
    var body: some View {
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
                    Button(action: { Task { await viewModel.refresh() } }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
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
            if let repository, let apiClient {
                let addMetricViewModel = AddMetricViewModel(
                    repository: repository,
                    apiClient: apiClient,
                    userId: viewModel.user.id
                )
                AddMetricView(viewModel: addMetricViewModel)
                    .onDisappear {
                        // Refresh metrics after adding
                        Task {
                            await viewModel.refresh()
                        }
                    }
            } else {
                Text("Error: Dependencies not available")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating Action Button
            Button(action: { showingAddMetric = true }, label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4, x: 2, y: 2)
            })
            .padding()
            .accessibilityLabel("Add new health metric")
        }
    }
    
    private var commonMetricTypes: [HealthMetricType] {
        [.heartRate, .steps, .bloodPressureSystolic, .bloodGlucose, .weight]
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
