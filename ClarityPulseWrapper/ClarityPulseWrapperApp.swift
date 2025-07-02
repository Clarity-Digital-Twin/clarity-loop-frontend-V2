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
import Amplify

@main
struct ClarityPulseWrapperApp: App {
    private let appState = AppState()
    private let dependencies: Dependencies
    @State private var email = ""
    @State private var password = ""

    init() {
        // Configure dependencies ONCE
        let deps = Dependencies()
        let configurator = AppDependencyConfigurator()
        configurator.configure(deps)
        self.dependencies = deps

        print("✅ Dependencies configured successfully")
        print("📱 ClarityPulseWrapperApp initialized")
        
        // Debug: Check if amplifyconfiguration.json is in bundle
        if let path = Bundle.main.path(forResource: "amplifyconfiguration", ofType: "json") {
            print("✅ amplifyconfiguration.json found at: \(path)")
            
            // Configure Amplify
            do {
                try Amplify.configure()
                print("✅ Amplify configured successfully")
            } catch {
                print("❌ Unable to configure Amplify: \(error)")
            }
        } else {
            print("❌ amplifyconfiguration.json NOT found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            print("📁 Resources: \(Bundle.main.resourcePath ?? "none")")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Use RootView which handles Amplify configuration and navigation
            RootView(dependencies: dependencies, appState: appState)
                .environment(appState)
                .environmentObject(dependencies)
                .onAppear {
                    print("🎯 RootView appeared")
                }
        }
}
