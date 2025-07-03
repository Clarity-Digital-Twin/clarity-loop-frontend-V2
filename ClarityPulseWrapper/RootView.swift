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
                            Text("⏱️ \(max(0, 10 - initializationTimer))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }

                    if showSkipOption {
                        Button("Skip AWS Setup") {
                            stopTimer()
                            isInitializing = false
                            configurationError = TimeoutError(seconds: 10)
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
            // Use a more robust timeout mechanism
            let result = try await withThrowingTaskGroup(of: Void.self) { group in
                // Add the Amplify configuration task
                group.addTask {
                    let amplifyConfig = AmplifyConfiguration()
                    try await amplifyConfig.configure()
                    print("✅ Amplify configured successfully in RootView")
                }

                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    throw TimeoutError(seconds: 30)
                }

                // Wait for the first one to complete
                try await group.next()

                // Cancel all remaining tasks
                group.cancelAll()
            }

            // If we get here, Amplify was configured successfully
            await MainActor.run {
                stopTimer()
                isAmplifyConfigured = true
                isInitializing = false
                print("📌 RootView state updated - isInitializing: \(isInitializing), isAmplifyConfigured: \(isAmplifyConfigured)")
            }

        } catch {
            print("❌ Failed to configure Amplify: \(error)")
            await MainActor.run {
                stopTimer()
                configurationError = error
                isInitializing = false
                print("📌 RootView error state - isInitializing: \(isInitializing), error: \(error)")
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
                if initializationTimer >= 30 || !isInitializing {
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

// MARK: - Timeout Error
private struct TimeoutError: LocalizedError {
    let seconds: TimeInterval

    var errorDescription: String? {
        return "Configuration timed out after \(Int(seconds)) seconds. You can skip AWS setup and continue with local features."
    }
}
