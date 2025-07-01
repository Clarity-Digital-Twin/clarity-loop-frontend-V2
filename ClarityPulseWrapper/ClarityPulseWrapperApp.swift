//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Minimal wrapper to create iOS app bundle from SPM package
//

import SwiftUI
import SwiftData
import ClarityCore
import ClarityDomain
import ClarityData
import ClarityUI

@main
struct ClarityPulseWrapperApp: App {
    @State private var appState = AppState()
    private let dependencies: Dependencies
    
    init() {
        // Configure dependencies ONCE
        let deps = Dependencies()
        let configurator = AppDependencyConfigurator()
        configurator.configure(deps)
        self.dependencies = deps
        
        print("✅ Dependencies configured successfully")
        print("📱 ClarityPulseWrapperApp initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .environment(appState)
                .withDependencies(dependencies)
                .onAppear {
                    print("🚀 LoginView appeared in WindowGroup")
                }
        }
    }
}

// RootContainerView removed - dependencies now injected directly in App
