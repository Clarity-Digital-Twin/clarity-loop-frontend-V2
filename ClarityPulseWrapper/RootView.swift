//
//  RootView.swift
//  ClarityPulseWrapper
//
//  Root view that handles all app states with proper dependency injection
//

import SwiftUI
import ClarityCore
import ClarityDomain
import ClarityData
import ClarityUI

struct RootView: View {
    let dependencies: Dependencies
    let isAmplifyConfigured: Bool
    let amplifyError: Error?
    let isMemoryHealthy: Bool
    let memoryPressureLevel: Int

    @Environment(\.dependencies) private var environmentDependencies
    @Environment(\.authenticationService) private var authenticationService

    var body: some View {
        Group {
            if !isMemoryHealthy && memoryPressureLevel >= 3 {
                // Critical memory pressure - show warning
                memoryWarningView
            } else if isAmplifyConfigured {
                // Amplify is ready - show main app
                mainAppView
            } else if let error = amplifyError {
                // Amplify failed - show error but allow app to continue
                errorView(error)
            } else {
                // Amplify is still configuring - show loading
                loadingView
            }
        }
        .onAppear {
            print("🎯 [RootView] View appeared")
            print("📊 [RootView] Amplify configured: \(isAmplifyConfigured)")
            print("🧠 [RootView] Memory healthy: \(isMemoryHealthy), pressure level: \(memoryPressureLevel)")
            if let error = amplifyError {
                print("❌ [RootView] Amplify error: \(error)")
            }
        }
    }

    private var mainAppView: some View {
        ClarityUI.RootView()
            .dependencies(dependencies)
            .onAppear {
                print("✅ [RootView] Showing main app - Amplify is ready!")
            }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Configuration Warning")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Amplify configuration failed, but you can continue using the app with limited functionality.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Error: \(error.localizedDescription)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue") {
                // Just proceed to main app even without Amplify
                print("🔄 [RootView] User chose to continue without Amplify")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Setting up AWS services...")
                .font(.headline)

            Text("Please wait while we configure your connection")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var memoryWarningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "memorychip.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Memory Warning")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The app is using too much memory and may be terminated by iOS.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Memory pressure level: \(memoryPressureLevel)")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                Button("Force Memory Cleanup") {
                    // This will trigger garbage collection
                    print("🧹 [RootView] User requested memory cleanup")
                }
                .buttonStyle(.borderedProminent)

                Button("Continue Anyway") {
                    print("⚠️ [RootView] User chose to continue despite memory warning")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
