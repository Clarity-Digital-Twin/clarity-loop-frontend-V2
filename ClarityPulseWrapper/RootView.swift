//
//  RootView.swift
//  ClarityPulseWrapper
//
//  Root view that handles all app states with proper dependency injection
//

import SwiftUI
import ClarityCore
import ClarityDomain
import ClarityUI

struct RootView: View {
    @State private var isInitializing = true
    @State private var isAmplifyConfigured = false
    @State private var configurationError: Error?
    @State private var showLoginView = false
    
    let dependencies: Dependencies
    let appState: AppState
    
    var body: some View {
        ZStack {
            // Debug overlay
            VStack {
                HStack {
                    Text("showLoginView: \(showLoginView ? "true" : "false")")
                        .foregroundColor(.red)
                        .padding(5)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(5)
                    Spacer()
                }
                Spacer()
            }
            .zIndex(999)
            
            Group {
                if isInitializing {
                // Initialization screen
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Initializing...")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if let error = configurationError {
                // Error screen
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Configuration Failed")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if showLoginView {
                // Login view - inject dependencies properly
                let _ = print("🚀 Showing LoginView now! showLoginView = \(showLoginView)")
                LoginView(dependencies: dependencies)
                    .environment(appState)
                    .withDependencies(dependencies)
                    .onAppear {
                        print("🔍 LoginView container appeared")
                        print("🔍 Dependencies type: \(type(of: dependencies))")
                    }
            } else {
                // Landing view
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("CLARITY Pulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Health Companion")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Amplify configured successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Button {
                        print("🔘 Button tapped - showing LoginView")
                        print("🔘 Current showLoginView state: \(showLoginView)")
                        
                        // Toggle the state
                        showLoginView.toggle()
                        print("🔘 New showLoginView state: \(showLoginView)")
                    } label: {
                        Text("Continue to Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .onTapGesture {
                        print("🔘 TAP GESTURE - showing LoginView")
                        showLoginView = true
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            }
        }
        .task {
            // Configure Amplify
            print("🔄 Starting Amplify configuration task...")
            do {
                let amplifyConfig = dependencies.require(AmplifyConfigurable.self)
                try await amplifyConfig.configure()
                print("✅ Amplify configured successfully in task")
                
                // Small delay to ensure UI updates
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                isAmplifyConfigured = true
                isInitializing = false
                print("🏁 State updated: isAmplifyConfigured = \(isAmplifyConfigured), isInitializing = \(isInitializing)")
            } catch {
                print("❌ Failed to configure Amplify: \(error)")
                configurationError = error
                isInitializing = false
            }
        }
    }
}