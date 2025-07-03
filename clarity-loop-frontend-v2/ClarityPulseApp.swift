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

    /// Amplify initialization state
    @State private var amplifyConfigured = false

    // MARK: - Initialization

    init() {
        // Configure dependencies properly
        let configurator = AppDependencyConfigurator()
        configurator.configure(dependencies)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            if amplifyConfigured {
                RootView()
                    .environment(appState)
                    .withDependencies(dependencies)
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Initializing...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await initializeAmplify()
                }
            }
        }
    }

    // MARK: - Amplify Initialization

    private func initializeAmplify() async {
        do {
            // Configure Amplify directly without using DI to avoid actor isolation issues
            let amplifyConfig = AmplifyConfiguration()
            try await amplifyConfig.configure()
            print("✅ Amplify configured successfully in app startup")

            await MainActor.run {
                amplifyConfigured = true
            }
        } catch {
            print("❌ Failed to configure Amplify: \(error)")
            // Still allow app to continue - user can try to use it
            await MainActor.run {
                amplifyConfigured = true
            }
        }
    }
}

// MARK: - App State is imported from ClarityCore
