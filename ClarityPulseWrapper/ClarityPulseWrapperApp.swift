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

// 🎯 Timeout protection following Swift Concurrency best practices
enum AuthTimeout: Error {
    case timeout
    case cancelled
}

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
                    // ❌ Show error but allow retry
                    ErrorView(error: error) {
                        configureAmplify()
                    }
                } else {
                    // 🔄 Show loading while configuring
                    LoadingView(step: configurationStep)
                }
            }
            .onAppear {
                configureAmplify()
            }
        }
    }

    private func configureAmplify() {
        Task {
            await MainActor.run {
                amplifyError = nil
                configurationStep = "Configuring Amplify..."
            }

            do {
                try Amplify.add(plugin: AWSCognitoAuthPlugin())
                try Amplify.configure()

                await MainActor.run {
                    print("✅ [AMPLIFY] Configured successfully")
                    isAmplifyConfigured = true
                }
            } catch {
                await MainActor.run {
                    print("❌ [AMPLIFY] Configuration failed: \(error)")
                    amplifyError = error
                }
            }
        }
    }
}

// 🔐 Best practice auth service with timeout protection and cooperative cancellation
@MainActor
class SimpleAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var currentUser: String?

    func checkAuthState() async {
        print("🔐 [AUTH] Starting authentication check with timeout protection...")
        isCheckingAuth = true

        do {
            // 🎯 BEST PRACTICE: Use timeout protection with TaskGroup racing
            let authResult = try await withTimeout(seconds: 8.0) {
                return try await Amplify.Auth.fetchAuthSession()
            }

            if authResult.isSignedIn {
                // Get user details with timeout protection
                let userResult = try await withTimeout(seconds: 5.0) {
                    return try await Amplify.Auth.getCurrentUser()
                }

                currentUser = userResult.username
                isAuthenticated = true
                print("🔐 [AUTH] ✅ User is signed in: \(userResult.username)")
            } else {
                isAuthenticated = false
                currentUser = nil
                print("🔐 [AUTH] ❌ User is not signed in")
            }
        } catch AuthTimeout.timeout {
            print("🔐 [AUTH] ⏰ Authentication check timed out - treating as not authenticated")
            isAuthenticated = false
            currentUser = nil
        } catch AuthTimeout.cancelled {
            print("🔐 [AUTH] 🚫 Authentication check was cancelled")
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("🔐 [AUTH] ❌ Authentication check failed: \(error)")
            isAuthenticated = false
            currentUser = nil
        }

        isCheckingAuth = false
        print("🔐 [AUTH] Authentication check completed. Authenticated: \(isAuthenticated)")
    }

    func signIn(username: String, password: String) async throws {
        print("🔐 [AUTH] Attempting sign in for user: \(username)")

        // Check if already authenticated to avoid AuthError 5
        if isAuthenticated {
            print("🔐 [AUTH] ⚠️ User already authenticated, skipping sign-in")
            return
        }

        // 🎯 BEST PRACTICE: Timeout protection for sign-in
        let result = try await withTimeout(seconds: 15.0) {
            return try await Amplify.Auth.signIn(username: username, password: password)
        }

        if result.isSignedIn {
            await checkAuthState() // Refresh auth state
            print("🔐 [AUTH] ✅ Sign in successful")
        } else {
            print("🔐 [AUTH] ⚠️ Sign in requires additional steps: \(result.nextStep)")
        }
    }

    func signOut() async throws {
        print("🔐 [AUTH] Signing out...")

        // 🎯 BEST PRACTICE: Timeout protection for sign-out
        _ = try await withTimeout(seconds: 10.0) {
            return await Amplify.Auth.signOut()
        }

        isAuthenticated = false
        currentUser = nil
        print("🔐 [AUTH] ✅ Signed out successfully")
    }
}

// 🎯 BEST PRACTICE: Timeout implementation using TaskGroup racing pattern
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        let deadline = Date(timeIntervalSinceNow: seconds)

        // Start actual work
        group.addTask {
            try await operation()
        }

        // Start timeout task with deadline-based sleep
        group.addTask {
            let interval = deadline.timeIntervalSinceNow
            if interval > 0 {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            // 🎯 Check for cancellation before throwing timeout
            try Task.checkCancellation()
            throw AuthTimeout.timeout
        }

        // First task to complete wins
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

// 🔄 Loading view
struct LoadingView: View {
    let step: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(step)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// ❌ Error view with retry
struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Configuration Error")
                .font(.headline)

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// 🏠 Main authenticated app
struct AuthenticatedApp: View {
    @StateObject private var authService = SimpleAuthService()

    var body: some View {
        Group {
            if authService.isCheckingAuth {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Checking authentication...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .task {
                    await authService.checkAuthState()
                }
            } else if authService.isAuthenticated {
                DashboardView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}

// 🔐 Login view
struct LoginView: View {
    @EnvironmentObject private var authService: SimpleAuthService
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            Text("CLARITY")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Signing In..." : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func signIn() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }

            do {
                try await authService.signIn(username: username, password: password)
            } catch {
                await MainActor.run {
                    if let authError = error as? AuthError {
                        switch authError {
                        case .notAuthorized:
                            errorMessage = "Invalid username or password"
                        default:
                            errorMessage = "Sign in failed: \(authError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                    }
                    print("🔐 [AUTH] Sign in error: \(error)")
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// 📊 Dashboard view
struct DashboardView: View {
    @EnvironmentObject private var authService: SimpleAuthService

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Welcome to CLARITY")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let username = authService.currentUser {
                    Text("Hello, \(username)!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 20) {
                    DashboardCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Analytics",
                        description: "View your data insights"
                    )

                    DashboardCard(
                        icon: "person.2.circle",
                        title: "Collaboration",
                        description: "Work with your team"
                    )

                    DashboardCard(
                        icon: "gear.circle",
                        title: "Settings",
                        description: "Configure your preferences"
                    )
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// 📋 Dashboard card component
struct DashboardCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
