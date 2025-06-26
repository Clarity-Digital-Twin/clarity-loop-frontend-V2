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
    // TODO: Add AppState when implemented
    // @EnvironmentObject private var appState: AppState
    @State private var isAuthenticated = false
    
    public init() {}
    
    public var body: some View {
        Group {
            // TODO: Implement navigation based on AppState
            // For now, just show the login view
            if isAuthenticated {
                // Temporary user for testing
                MainTabView(user: User(
                    id: UUID(),
                    email: "test@example.com",
                    firstName: "Test",
                    lastName: "User",
                    createdAt: Date(),
                    updatedAt: Date()
                ))
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: isAuthenticated)
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