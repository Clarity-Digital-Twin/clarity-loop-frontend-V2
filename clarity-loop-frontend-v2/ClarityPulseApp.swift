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
    @State private var appState = AppState()
    
    // MARK: - Initialization
    
    init() {
        // Configure dependencies first
        AppDependencies().configure()
        
        // Get the ModelContainer from DI
        self.modelContainer = DIContainer.shared.require(ModelContainer.self)
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(appState)
        }
    }
}

// MARK: - App State is imported from ClarityCore
