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
    
    /// Dependencies container
    private let dependencies = Dependencies()
    
    /// App state management
    @State private var appState = AppState()
    
    // MARK: - Initialization
    
    init() {
        // Configure dependencies properly
        let configurator = AppDependencyConfigurator()
        configurator.configure(dependencies)
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .withDependencies(dependencies)
        }
    }
}

// MARK: - App State is imported from ClarityCore
