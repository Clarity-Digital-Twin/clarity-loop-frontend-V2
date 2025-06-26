//
//  RootView.swift
//  clarity-loop-frontend-v2
//
//  Root view that handles navigation based on authentication
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct RootView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        Group {
            if appState.isLoading {
                LoadingView()
            } else if appState.isAuthenticated, let user = appState.currentUser {
                MainTabView(user: user)
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    let user: User
    
    var body: some View {
        TabView {
            DashboardView(user: user)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
            
            HealthMetricsView()
                .tabItem {
                    Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            ProfileView(user: user)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}