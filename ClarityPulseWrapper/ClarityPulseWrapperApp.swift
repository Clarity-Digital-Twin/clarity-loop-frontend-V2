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
        } else {
            print("❌ amplifyconfiguration.json NOT found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            print("📁 Resources: \(Bundle.main.resourcePath ?? "none")")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Test - show a simple view directly
            VStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("CLARITY Pulse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Login Screen")
                    .font(.title2)
                
                // Add simple login fields
                VStack(spacing: 16) {
                    TextField("Email", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    SecureField("Password", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Button("Sign In") {
                        print("Sign in tapped")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}
