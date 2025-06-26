//
//  ClarityPulseApp.swift
//  ClarityPulse
//
//  Created on 2025-06-25.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import SwiftUI
import SwiftData
import ClarityCore
import ClarityDomain
import ClarityUI
import ClarityData

@main
struct ClarityPulseApp: App {
    // MARK: - Properties
    
    /// SwiftData model container
    private let modelContainer: ModelContainer
    
    /// App state management
    @StateObject private var appState = AppState()
    
    // MARK: - Initialization
    
    init() {
        // Configure dependencies first
        AppDependencies().configure()
        
        // Initialize ModelContainer with our models
        do {
            let schema = Schema([
                PersistedUser.self,
                PersistedHealthMetric.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environmentObject(appState)
                .task {
                    await appState.initialize()
                }
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    
    private let container = DIContainer.shared
    
    func initialize() async {
        isLoading = true
        
        // Check authentication status
        await checkAuthStatus()
        
        isLoading = false
    }
    
    private func checkAuthStatus() async {
        guard let authService = container.resolve(AuthServiceProtocol.self) else { 
            print("AuthService not found in DI container")
            return 
        }
        
        do {
            currentUser = try await authService.getCurrentUser()
            isAuthenticated = currentUser != nil
        } catch {
            print("Auth check failed: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    func login(with user: User) {
        currentUser = user
        isAuthenticated = true
    }
    
    func logout() async {
        if let authService = container.resolve(AuthServiceProtocol.self) {
            try? await authService.logout()
        }
        currentUser = nil
        isAuthenticated = false
    }
}