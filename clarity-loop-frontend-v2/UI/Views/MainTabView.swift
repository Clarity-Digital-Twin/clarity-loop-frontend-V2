//
//  MainTabView.swift
//  clarity-loop-frontend-v2
//
//  Main tab navigation after authentication
//

import SwiftUI
import ClarityCore

public struct MainTabView: View {
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            Text("Health Metrics")
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
            
            Text("Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}