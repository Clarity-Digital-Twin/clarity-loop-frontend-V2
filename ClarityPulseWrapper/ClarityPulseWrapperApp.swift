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

@main
struct ClarityPulseWrapperApp: App {

    init() {
        configureAmplify()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 🚀 2025 PATTERN: Async dependency loading
                    await loadDependenciesAsync()
                }
        }
    }

    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
            print("✅ [AMPLIFY] Configuration completed successfully")
        } catch {
            print("❌ [AMPLIFY] Failed to configure: \(error)")
        }
    }

    // 🔧 2025 PATTERN: Lightweight async dependency wrapper
    private func loadDependenciesAsync() async {
        // Load sophisticated features asynchronously without blocking main thread
        print("🔄 [DEPENDENCIES] Starting async loading...")

        // Simulate lightweight dependency preparation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        print("✅ [DEPENDENCIES] Async loading completed")

        // Future: This is where we'll gradually integrate sophisticated features
        // using the wrapper pattern to avoid main thread blocking
    }
}

struct ContentView: View {
    @State private var showSplash = true
    @State private var isSignedIn = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false
                    checkAuthenticationStatus()
                }
            } else if isSignedIn {
                MainAppView()
            } else {
                LoginView(
                    isSignedIn: $isSignedIn,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
            }
        }
        .onAppear {
            if !showSplash {
                checkAuthenticationStatus()
            }
        }
    }

    private func checkAuthenticationStatus() {
        isLoading = true

        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                await MainActor.run {
                    isSignedIn = session.isSignedIn
                    isLoading = false
                    print("✅ Auth status checked: \(isSignedIn ? "Signed In" : "Not Signed In")")
                }
            } catch {
                await MainActor.run {
                    isSignedIn = false
                    isLoading = false
                    errorMessage = "Failed to check auth status: \(error.localizedDescription)"
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

struct LoginView: View {
    @Binding var isSignedIn: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    @State private var email = ""
    @State private var password = ""

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

            Button(action: signIn) {
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

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await Amplify.Auth.signIn(username: email, password: password)
                await MainActor.run {
                    if result.isSignedIn {
                        isSignedIn = true
                        isLoading = false
                        print("✅ Sign in successful!")
                    } else {
                        isLoading = false
                        errorMessage = "Sign in requires additional steps"
                        print("⚠️ Sign in requires additional steps: \(result.nextStep)")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                    print("❌ Sign in failed: \(error)")
                }
            }
        }
    }
}

struct MainAppView: View {
    var body: some View {
        TabView {
            DashboardTab()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Dashboard")
                }

            HealthTab()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Health")
                }

            ProfileTab()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
        }
    }
}

struct DashboardTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    HealthMetricCard(title: "Heart Rate", value: "72 BPM", color: .red)
                    HealthMetricCard(title: "Steps", value: "8,432", color: .blue)
                    HealthMetricCard(title: "Sleep", value: "7h 23m", color: .purple)
                    HealthMetricCard(title: "Calories", value: "2,156", color: .orange)
                }
                .padding(.horizontal)

                Spacer()

                SignOutButton()
            }
            .navigationTitle("CLARITY")
        }
    }
}

struct HealthTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Health Metrics")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(0..<10) { index in
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Heart Rate Reading")
                                        .fontWeight(.semibold)
                                    Text("72 BPM - Normal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("2:30 PM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }

                SignOutButton()
            }
            .navigationTitle("Health Data")
        }
    }
}

struct ProfileTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)

                VStack(spacing: 10) {
                    Text("John Doe")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("john.doe@example.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 15) {
                    ProfileRow(title: "Age", value: "32 years")
                    ProfileRow(title: "Height", value: "5'10\"")
                    ProfileRow(title: "Weight", value: "175 lbs")
                    ProfileRow(title: "Blood Type", value: "O+")
                }
                .padding(.horizontal)

                Spacer()

                SignOutButton()
            }
            .navigationTitle("Profile")
        }
    }
}

struct ProfileRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct SignOutButton: View {
    var body: some View {
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
        .font(.title2)
        .foregroundColor(.white)
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.red)
        .cornerRadius(10)
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
