//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Created on 2025.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import SwiftUI
import Amplify
import AWSCognitoAuthPlugin

@main
struct ClarityPulseWrapperApp: App {
    @State private var isAmplifyConfigured = false
    @State private var amplifyError: Error?
    @State private var configurationStep = "Starting..."

    var body: some Scene {
        WindowGroup {
            Group {
                if isAmplifyConfigured {
                    // ✅ Once Amplify is ready, show the simple authenticated app
                    AuthenticatedApp()
                } else if let error = amplifyError {
                    // ❌ Show error but allow proceeding
                    ErrorView(error: error) {
                        // Proceed without Amplify
                        isAmplifyConfigured = true
                    }
                } else {
                    // ⏳ Still configuring Amplify
                    LoadingView(step: configurationStep)
                }
            }
            .task {
                await configureAmplify()
            }
        }
    }

    private func configureAmplify() async {
        print("🔧 [AMPLIFY] Starting configuration...")
        configurationStep = "Adding plugins..."

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            print("🔧 [AMPLIFY] Added Cognito plugin")

            configurationStep = "Loading configuration..."
            try Amplify.configure()
            print("🔧 [AMPLIFY] Configuration completed successfully!")

            await MainActor.run {
                isAmplifyConfigured = true
            }
        } catch {
            print("❌ [AMPLIFY] Configuration failed: \(error)")
            await MainActor.run {
                amplifyError = error
            }
        }
    }
}

// 🎯 Simple authenticated app without heavy dependencies
struct AuthenticatedApp: View {
    @State private var authService = SimpleAuthService()

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 🎉 User is logged in - show simple dashboard
                SimpleDashboard()
                    .environmentObject(authService)
            } else {
                // 🔐 User needs to log in
                SimpleLoginView()
                    .environmentObject(authService)
            }
        }
        .task {
            await authService.checkAuthState()
        }
    }
}

// 🔐 Lightweight login view
struct SimpleLoginView: View {
    @EnvironmentObject var authService: SimpleAuthService
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("CLARITY Digital Twin")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)

            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private func login() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                try await authService.signIn(username: username, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// 🎉 Simple dashboard to verify navigation works
struct SimpleDashboard: View {
    @EnvironmentObject var authService: SimpleAuthService

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("🎉 Welcome to CLARITY!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Authentication successful!")
                    .font(.title2)
                    .foregroundColor(.green)

                if let userId = authService.currentUser {
                    Text("User ID: \(userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                VStack(spacing: 16) {
                    NavigationLink("📊 Dashboard") {
                        Text("Dashboard Content")
                            .font(.title)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink("💬 Messages") {
                        Text("Messages Content")
                            .font(.title)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink("⚙️ Settings") {
                        Text("Settings Content")
                            .font(.title)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Sign Out") {
                    Task {
                        await authService.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("CLARITY")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ⚠️ Error view that allows proceeding
struct ErrorView: View {
    let error: Error
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Configuration Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AWS configuration failed, but you can continue with limited functionality.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue Anyway", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// ⏳ Loading view
struct LoadingView: View {
    let step: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Setting up CLARITY...")
                .font(.headline)

            Text(step)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// 🔐 Lightweight auth service without heavy dependencies
@MainActor
class SimpleAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: String?

    func checkAuthState() async {
        print("🔐 [AUTH] Checking current auth state...")

        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            if session.isSignedIn {
                // Get user details
                let user = try await Amplify.Auth.getCurrentUser()
                isAuthenticated = true
                currentUser = user.userId
                print("🔐 [AUTH] User is signed in: \(user.userId)")
            } else {
                isAuthenticated = false
                currentUser = nil
                print("🔐 [AUTH] No current session")
            }
        } catch {
            print("❌ [AUTH] Error checking auth state: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }

    func signIn(username: String, password: String) async throws {
        print("🔐 [AUTH] Attempting sign in for: \(username)")

        let result = try await Amplify.Auth.signIn(
            username: username,
            password: password
        )

        if result.isSignedIn {
            let user = try await Amplify.Auth.getCurrentUser()
            isAuthenticated = true
            currentUser = user.userId
            print("✅ [AUTH] Sign in successful: \(user.userId)")
        }
    }

    func signOut() async {
        do {
            _ = try await Amplify.Auth.signOut()
            isAuthenticated = false
            currentUser = nil
            print("👋 [AUTH] Sign out successful")
        } catch {
            print("❌ [AUTH] Sign out error: \(error)")
        }
    }
}
