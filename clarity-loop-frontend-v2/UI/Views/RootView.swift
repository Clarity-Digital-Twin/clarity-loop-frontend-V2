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
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        Group {
            // TODO: Implement navigation based on AppState
            // For now, just show the login view
            if appState.isAuthenticated {
                // Temporary user for testing
                MainTabView(
                    userId: appState.currentUserId ?? UUID(),
                    userName: appState.currentUserName ?? "User",
                    userEmail: appState.currentUserEmail ?? "user@example.com"
                )
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
        .background(Color.primary.opacity(0.05))
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    let userId: UUID
    let userName: String
    let userEmail: String
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
            
            HealthMetricsView()
                .tabItem {
                    Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}