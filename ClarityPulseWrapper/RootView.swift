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
import ClarityData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isInitializing = true
    @State private var isAmplifyConfigured = false
    @State private var configurationError: Error?
    @State private var showLoginView = false
    @State private var initializationTimer = 0
    @State private var showSkipOption = false
    @State private var timer: Timer?

    let dependencies: Dependencies

    var body: some View {
        Group {
            if isInitializing {
                // Enhanced initialization screen with progress feedback
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    VStack(spacing: 8) {
                        Text("Initializing...")
                            .font(.title2)

                        Text("Setting up AWS services...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if initializationTimer > 0 {
                            Text("⏱️ \(max(0, 15 - initializationTimer))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }

                    if showSkipOption {
                        Button("Skip AWS Setup") {
                            stopTimer()
                            isInitializing = false
                            configurationError = AmplifyConfigurationError.timeout(15)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    startTimer()
                }
                .onDisappear {
                    stopTimer()
                }
            } else if let error = configurationError {
                // Error screen with option to skip AWS setup
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("AWS Configuration Issue")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(error.localizedDescription)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button("Retry AWS Setup") {
                            isInitializing = true
                            configurationError = nil
                            Task {
                                await configureAmplify()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Skip & Continue with Local Features") {
                            configurationError = nil
                            // Continue without AWS - app will use mock/local services
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top)

                    Text("💡 Tip: You can skip AWS setup during development and still use the app with local features.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if showLoginView {
                // Login view
                LoginView(dependencies: dependencies)
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
            // GIVEN: Use singleton AmplifyConfiguration with proper BDD approach
            print("📋 [RootView] GIVEN: Using AmplifyConfiguration singleton")

            // WHEN: Configure Amplify using the robust singleton
            try await AmplifyConfiguration.shared.configure()

            // THEN: Configuration successful
            await MainActor.run {
                stopTimer()
                isAmplifyConfigured = true
                isInitializing = false
                print("✅ [RootView] THEN: Configuration completed - App ready")
            }

        } catch let error as AmplifyConfigurationError {
            print("❌ [RootView] THEN: AmplifyConfigurationError - \(error.errorDescription ?? "Unknown error")")
            await handleConfigurationError(error)

        } catch {
            print("❌ [RootView] THEN: Unexpected error - \(error)")
            await handleConfigurationError(AmplifyConfigurationError.amplifyConfigurationError(error))
        }
    }

    private func handleConfigurationError(_ error: AmplifyConfigurationError) async {
        await MainActor.run {
            stopTimer()
            configurationError = error
            isInitializing = false

            // Log the specific error type for debugging
            switch error {
            case .timeout(let seconds):
                print("🕐 [RootView] Configuration timed out after \(seconds) seconds")
            case .configurationFileNotFound:
                print("📁 [RootView] amplifyconfiguration.json not found in bundle")
            case .missingAuthConfiguration:
                print("🔐 [RootView] Auth configuration missing from config file")
            default:
                print("⚠️ [RootView] Other configuration error: \(error.errorDescription ?? "Unknown")")
            }
        }
    }

    // MARK: - Helper Methods
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                initializationTimer += 1
                if initializationTimer >= 10 {
                    showSkipOption = true
                }
                if initializationTimer >= 15 || !isInitializing {
                    stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
