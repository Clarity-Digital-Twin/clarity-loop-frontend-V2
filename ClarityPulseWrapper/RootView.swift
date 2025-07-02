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
                    
                    Button("Retry") {
                        isInitializing = true
                        configurationError = nil
                        Task {
                            await configureAmplify()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if showLoginView {
                // Login view - inject dependencies properly
                LoginView(dependencies: dependencies)
                    .environment(appState)
                    .withDependencies(dependencies)
            } else {
                // Landing view
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.multicolor)
                    
                    VStack(spacing: 8) {
                        Text("CLARITY Pulse")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your Health Companion")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut) {
                            showLoginView = true
                        }
                    }) {
                        Text("Continue to Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .task {
            await configureAmplify()
        }
    }
    
    private func configureAmplify() async {
        print("🔄 Starting Amplify configuration...")
        do {
            if let amplifyConfig = dependencies.resolve(AmplifyConfigurable.self) {
                try await amplifyConfig.configure()
                print("✅ Amplify configured successfully")
            } else {
                print("⚠️ AmplifyConfigurable not found in dependencies, skipping...")
            }
            
            isAmplifyConfigured = true
            isInitializing = false
        } catch {
            print("❌ Failed to configure Amplify: \(error)")
            configurationError = error
            isInitializing = false
        }
    }
}