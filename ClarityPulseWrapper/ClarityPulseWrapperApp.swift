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
                    // ✅ Once Amplify is ready, show the authenticated app
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

// 🎯 Fixed authenticated app with proper auth state management
struct AuthenticatedApp: View {
    @State private var authService = SimpleAuthService()

    var body: some View {
        Group {
            if authService.isCheckingAuth {
                // 🔄 Still checking auth state - show loading
                LoadingView(step: "Checking authentication...")
            } else if authService.isAuthenticated {
                // 🎉 User is authenticated - show dashboard
                SimpleDashboard()
                    .environmentObject(authService)
            } else {
                // 🔐 User needs to authenticate - show login
                SimpleLoginView()
                    .environmentObject(authService)
            }
        }
        .task {
            await authService.checkAuthState()
        }
    }
}

// 🔐 Fixed login view with better error handling
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
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
        .onAppear {
            // 🔍 Debug: Log when login view appears
            print("🔐 [LOGIN] Login view appeared")
            print("🔐 [LOGIN] Auth state - authenticated: \(authService.isAuthenticated), checking: \(authService.isCheckingAuth)")
        }
    }

    private func login() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                try await authService.signIn(username: username, password: password)
                // Reset form on success
                await MainActor.run {
                    username = ""
                    password = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 🎯 Better error handling for specific auth errors
                    if error.localizedDescription.contains("already") {
                        errorMessage = "You're already signed in. Refreshing..."
                        // Force refresh auth state
                        Task {
                            await authService.checkAuthState()
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
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
        .onAppear {
            print("🎉 [DASHBOARD] Dashboard appeared for user: \(authService.currentUser ?? "unknown")")
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

// 🔐 Fixed auth service with timeout protection and comprehensive error handling
@MainActor
class SimpleAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true  // 🎯 Track checking state
    @Published var currentUser: String?

    func checkAuthState() async {
        print("🔐 [AUTH] Starting authentication check...")
        isCheckingAuth = true

        do {
            // 🎯 Add timeout protection (5 seconds max)
            let authCheck = Task {
                let session = try await Amplify.Auth.fetchAuthSession()
                if session.isSignedIn {
                    // Get user details
                    let user = try await Amplify.Auth.getCurrentUser()
                    return (true, user.userId)
                } else {
                    return (false, nil)
                }
            }

            // Wait for auth check or timeout
            let result = try await withThrowingTaskGroup(of: (Bool, String?).self) { group in
                group.addTask {
                    return try await authCheck.value
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    throw AuthCheckError.timeout
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            isAuthenticated = result.0
            currentUser = result.1

            if isAuthenticated {
                print("✅ [AUTH] User is signed in: \(currentUser ?? "unknown")")
            } else {
                print("🔐 [AUTH] No current session - user needs to login")
            }

        } catch {
            print("⚠️ [AUTH] Auth check failed: \(error)")
            // 🎯 On any error, assume not authenticated and continue
            isAuthenticated = false
            currentUser = nil

            if error is AuthCheckError {
                print("⏰ [AUTH] Auth check timed out - proceeding to login")
            }
        }

        isCheckingAuth = false  // 🎯 ALWAYS set this to false
        print("🔐 [AUTH] Auth check complete - isAuthenticated: \(isAuthenticated)")
    }

    func signIn(username: String, password: String) async throws {
        print("🔐 [AUTH] Attempting sign in for: \(username)")

        // 🎯 Check if already signed in BEFORE attempting login
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            if session.isSignedIn {
                print("✅ [AUTH] User already signed in, updating state...")
                let user = try await Amplify.Auth.getCurrentUser()
                isAuthenticated = true
                currentUser = user.userId
                return  // Don't attempt sign in again
            }
        } catch {
            print("⚠️ [AUTH] Could not check existing session: \(error)")
            // Continue with sign in attempt
        }

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

// 🎯 Custom error for auth timeout
enum AuthCheckError: Error {
    case timeout
}
