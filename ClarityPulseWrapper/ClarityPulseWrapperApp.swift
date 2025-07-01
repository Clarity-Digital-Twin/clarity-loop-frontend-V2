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
    private let dependencies = Dependencies()
    
    init() {
        // Configure Dependencies properly - NO MORE BRIDGES!
        let configurator = AppDependencyConfigurator()
        configurator.configure(dependencies)
    }
    
    var body: some Scene {
        WindowGroup {
            // Create a root view that properly initializes everything
            RootContainerView(dependencies: dependencies, appState: appState)
        }
    }
}

// Container view that ensures dependencies are available before any child views render
struct RootContainerView: View {
    let dependencies: Dependencies
    let appState: AppState
    
    var body: some View {
        LoginView()
            .environment(appState)
            .withDependencies(dependencies)
            .onAppear {
                print("🚀 RootContainerView appeared")
                print("📦 Dependencies: \(dependencies)")
                
                // Verify critical dependencies are registered
                if let factory = dependencies.resolve(LoginViewModelFactory.self) {
                    print("✅ LoginViewModelFactory is available")
                } else {
                    print("❌ LoginViewModelFactory is nil!")
                }
            }
    }
}
