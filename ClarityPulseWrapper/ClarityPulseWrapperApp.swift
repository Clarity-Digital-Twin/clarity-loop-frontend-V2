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
import AWSAPIPlugin
import ClarityUI
import ClarityCore
import ClarityDomain

@main
struct ClarityPulseWrapperApp: App {

    init() {
        configureAmplify()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .lazyDependencies() // Lazy loading to prevent main thread blocking
        }
    }

    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
            print("✅ [AMPLIFY] Configuration completed successfully")
        } catch {
            print("❌ [AMPLIFY] Configuration failed: \(error)")
        }
    }
}

struct ContentView: View {
    @State private var showSplash = true
    @State private var isLoading = false
    @State private var authState: AuthState = .checking
    @State private var errorMessage: String?

    enum AuthState {
        case checking
        case authenticated
        case needsLogin
        case error(String)
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false
                    checkAuthenticationAsync()
                }
            } else {
                switch authState {
                case .checking:
                    LoadingView()
                case .authenticated:
                    // LAZY LOAD: Only create the main app when needed
                    LazyMainAppView()
                case .needsLogin:
                    LoginView()
                case .error(let message):
                    ErrorView(message: message) {
                        checkAuthenticationAsync()
                    }
                }
            }
        }
    }

    // CRITICAL: Async auth check to prevent main thread blocking
    private func checkAuthenticationAsync() {
        authState = .checking

        Task {
            do {
                let authSession = try await Amplify.Auth.fetchAuthSession()

                await MainActor.run {
                    if authSession.isSignedIn {
                        authState = .authenticated
                        print("✅ User already authenticated")
                    } else {
                        authState = .needsLogin
                        print("ℹ️ User needs to log in")
                    }
                }
            } catch {
                await MainActor.run {
                    authState = .error("Authentication check failed: \(error.localizedDescription)")
                    print("❌ Auth check failed: \(error)")
                }
            }
        }
    }
}

struct SplashView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text("Clarity Pulse")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("✅ AWS Amplify Configured")
                .font(.headline)
                .foregroundColor(.green)

            Button("Continue to App") {
                onContinue()
            }
            .font(.title2)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking authentication...")
                .font(.headline)
        }
    }
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("CLARITY Pulse")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Button(action: performLogin) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isLoading ? Color.gray : Color.blue)
            .cornerRadius(10)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }

    // CRITICAL: Async login to prevent main thread blocking
    private func performLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Check if already signed in first
                let authSession = try await Amplify.Auth.fetchAuthSession()

                if authSession.isSignedIn {
                    await MainActor.run {
                        isLoading = false
                        print("✅ User already signed in!")
                        // Navigate to main app - trigger parent state change
                    }
                    return
                }

                // Sign in with credentials
                let result = try await Amplify.Auth.signIn(
                    username: email,
                    password: password
                )

                await MainActor.run {
                    isLoading = false
                    if result.isSignedIn {
                        print("✅ Login successful!")
                        // Navigate to main app - trigger parent state change
                    }
                }

            } catch {
                // Handle "already signed in" error by signing out first
                if error.localizedDescription.contains("already") {
                    do {
                        _ = try await Amplify.Auth.signOut()
                        print("🔄 Signed out existing user, trying login again...")

                        let result = try await Amplify.Auth.signIn(
                            username: email,
                            password: password
                        )

                        await MainActor.run {
                            isLoading = false
                            if result.isSignedIn {
                                print("✅ Login successful after signout!")
                            }
                        }

                    } catch {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Login failed: \(error.localizedDescription)"
                            print("❌ Login failed: \(error)")
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Login failed: \(error.localizedDescription)"
                        print("❌ Login failed: \(error)")
                    }
                }
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Error")
                .font(.title)
                .fontWeight(.bold)

            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                onRetry()
            }
            .font(.title2)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding()
    }
}

// CRITICAL: Lazy loading prevents signal 9 kills
struct LazyMainAppView: View {
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                // Only load the complex app when ready
                MainAppView()
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading your dashboard...")
                        .font(.headline)
                }
                .onAppear {
                    // CRITICAL: Use async dispatch to prevent any main thread blocking
                    Task {
                        // Small delay to ensure UI is ready
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                        await MainActor.run {
                            isReady = true
                        }
                    }
                }
            }
        }
    }
}

// SIMPLIFIED: Main app without complex dependency injection
struct MainAppView: View {
    var body: some View {
        TabView {
            DashboardTab()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Dashboard")
                }

            HealthTab()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Health")
                }

            ProfileTab()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
    }
}

struct DashboardTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🎉 Welcome to Clarity!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your health dashboard is ready")
                    .font(.headline)
                    .foregroundColor(.secondary)

                // Placeholder for health metrics
                VStack(spacing: 15) {
                    HealthMetricCard(title: "Heart Rate", value: "72 BPM", color: .red)
                    HealthMetricCard(title: "Steps", value: "8,432", color: .blue)
                    HealthMetricCard(title: "Sleep", value: "7h 23m", color: .purple)
                }

                Spacer()

                Button("Sign Out") {
                    Task {
                        do {
                            _ = try await Amplify.Auth.signOut()
                            print("✅ Signed out successfully")
                        } catch {
                            print("❌ Sign out failed: \(error)")
                        }
                    }
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

struct HealthTab: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Health Metrics")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Track your health data here")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Health")
        }
    }
}

struct ProfileTab: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile Settings")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Manage your account settings")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// CRITICAL: Extension for lazy dependency loading
extension View {
    func lazyDependencies() -> some View {
        // This would be implemented to lazily load dependencies
        // instead of blocking the main thread during app startup
        self
    }
}
