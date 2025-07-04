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

// 🎯 Test minimal module access first
#if canImport(ClarityDomain)
import ClarityDomain
#endif

#if canImport(ClarityCore)
import ClarityCore
#endif

#if canImport(ClarityData)
import ClarityData
#endif

#if canImport(ClarityUI)
import ClarityUI
#endif

// 🎯 Timeout protection following Swift Concurrency best practices
enum AuthTimeout: Error {
    case timeout
    case cancelled
}

enum ConfigurationError: Error, LocalizedError {
    case missingFile
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "amplifyconfiguration.json is missing from bundle"
        case .invalidJSON:
            return "amplifyconfiguration.json contains invalid JSON"
        }
    }
}

// Helper function for timeout protection
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AuthTimeout.timeout
        }
        
        guard let result = try await group.next() else {
            throw AuthTimeout.timeout
        }
        
        group.cancelAll()
        return result
    }
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
                    // ✅ Use the sophisticated dependency injection system
                    #if canImport(ClarityCore) && canImport(ClarityData) && canImport(ClarityUI)
                    RealClarityApp()
                    #else
                    SimpleClarityApp()
                    #endif
                } else if let error = amplifyError {
                    // ❌ Show error but allow retry
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Configuration Error")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry") {
                            Task { await configureAmplify() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // ⏳ Show configuration progress
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(configurationStep)
                            .font(.headline)
                    }
                    .padding()
                }
            }
            .task {
                await configureAmplify()
            }
        }
    }

    // MARK: - Amplify Configuration with Timeout Protection

    @MainActor
    private func configureAmplify() async {
        configurationStep = "Validating configuration..."

        do {
            // 🎯 STEP 0: Assert configuration file exists
            guard let configURL = Bundle.main.url(forResource: "amplifyconfiguration", withExtension: "json") else {
                throw ConfigurationError.missingFile
            }
            print("✅ [AMPLIFY] Found config file at: \(configURL)")
            
            // Validate JSON is readable
            let configData = try Data(contentsOf: configURL)
            _ = try JSONSerialization.jsonObject(with: configData, options: [])
            print("✅ [AMPLIFY] Config JSON is valid, size: \(configData.count) bytes")
            
            // Enable verbose logging for diagnostics
            Amplify.Logging.logLevel = .verbose
            print("🔍 [AMPLIFY] Verbose logging enabled")
            
            configurationStep = "Adding Amplify plugins..."
            
            // 🎯 STEP 1: Add required plugins in correct order
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            print("✅ [AMPLIFY] Added AWSCognitoAuthPlugin and AWSAPIPlugin")

            configurationStep = "Configuring Amplify..."

            // 🎯 STEP 2: Configure Amplify with proper timeout protection
            // Since Amplify.configure() is synchronous and might block, we need a different approach
            let configurationCompleted = try await withThrowingTaskGroup(of: Bool.self) { group in
                // Configuration task
                group.addTask {
                    // Run on a background thread to avoid blocking main thread
                    await Task.detached(priority: .userInitiated) {
                        do {
                            try Amplify.configure()
                            print("✅ [AMPLIFY] Amplify configured successfully")
                            return true
                        } catch {
                            print("❌ [AMPLIFY] Configuration error: \(error)")
                            throw error
                        }
                    }.value
                }
                
                // Timeout task - 30 seconds for cold start with JWKS fetch
                group.addTask {
                    try await Task.sleep(for: .seconds(30))
                    print("⏰ [AMPLIFY] Configuration timeout reached after 30 seconds")
                    throw AuthTimeout.timeout
                }
                
                // Get the first result (either success or timeout)
                let result = try await group.next()!
                
                // Cancel remaining tasks
                group.cancelAll()
                
                return result
            }

            // 🎯 STEP 3: Verify configuration by checking session
            configurationStep = "Verifying configuration..."
            let startTime = Date()
            
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                let elapsed = Date().timeIntervalSince(startTime)
                print("✅ [AMPLIFY] Session check completed in \(elapsed)s")
                print("📊 [AMPLIFY] Is signed in: \(session.isSignedIn)")
                
                self.isAmplifyConfigured = true
                print("🎉 [AMPLIFY] Configuration completed successfully!")
            } catch {
                print("⚠️ [AMPLIFY] Session fetch failed after configure: \(error)")
                print("⚠️ [AMPLIFY] This may indicate a configuration issue")
                // Still mark as configured to allow app to continue
                self.isAmplifyConfigured = true
            }

        } catch AuthTimeout.timeout {
            print("⏰ [AMPLIFY] Configuration timed out after 30 seconds")
            print("⚠️ [AMPLIFY] Continuing without AWS services - app will work in offline mode")
            amplifyError = AuthTimeout.timeout
            // Still mark as configured to allow app to continue
            self.isAmplifyConfigured = true
        } catch {
            print("❌ [AMPLIFY] Configuration failed: \(error)")
            print("❌ [AMPLIFY] Error details: \(error.localizedDescription)")
            amplifyError = error
            // For non-timeout errors, also continue but log the error
            self.isAmplifyConfigured = true
        }
    }
}

// MARK: - Real Clarity App (Full System)

#if canImport(ClarityCore) && canImport(ClarityData) && canImport(ClarityUI)
struct RealClarityApp: View {
    var body: some View {
        // 🚀 Use the existing sophisticated dependency system
        MainTabView()
            .configuredDependencies() // This method comes from AppDependencies+SwiftUI.swift
    }
}
#endif

// MARK: - Simple Clarity App (Fallback)

struct SimpleClarityApp: View {
    var body: some View {
        // ✅ Simple fallback if modules aren't available
        SimpleAuthenticatedApp()
    }
}

// MARK: - Simple Authentication System (Fallback)

struct SimpleAuthenticatedApp: View {
    @StateObject private var authService = SimpleAmplifyAuthService()

    var body: some View {
        Group {
            if authService.isCheckingAuth {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Checking authentication...")
                        .font(.headline)
                }
                .padding()
            } else if authService.isAuthenticated {
                SimpleDashboard()
                    .environmentObject(authService)
            } else {
                SimpleLoginView()
                    .environmentObject(authService)
            }
        }
        .task {
            await authService.checkAuthState()
        }
    }
}

// 🔐 Simple auth service with timeout protection
@MainActor
class SimpleAmplifyAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var currentUser: String?
    @Published var errorMessage: String?

    func checkAuthState() async {
        print("🔐 [AUTH] Starting authentication check...")
        isCheckingAuth = true
        errorMessage = nil

        do {
            // 🎯 Add timeout protection (8 seconds max)
            try await withThrowingTaskGroup(of: Bool.self) { group in
                // Add auth check task
                group.addTask {
                    let session = try await Amplify.Auth.fetchAuthSession()
                    if session.isSignedIn {
                        // Get user details
                        let user = try await Amplify.Auth.getCurrentUser()
                        await MainActor.run {
                            self.currentUser = user.userId
                            self.isAuthenticated = true
                        }
                        print("🔐 [AUTH] User is signed in: \(user.userId)")
                        return true
                    } else {
                        await MainActor.run {
                            self.isAuthenticated = false
                            self.currentUser = nil
                        }
                        print("🔐 [AUTH] User is not signed in")
                        return false
                    }
                }

                // Add timeout task
                group.addTask {
                    try await Task.sleep(for: .seconds(8))
                    print("⏰ [AUTH] Authentication check timed out")
                    return false
                }

                // Get first result
                if let result = try await group.next() {
                    group.cancelAll()
                    await MainActor.run {
                        self.isAuthenticated = result
                    }
                }
            }

        } catch {
            print("❌ [AUTH] Auth check failed: \(error)")
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.errorMessage = "Authentication check failed"
            }
        }

        await MainActor.run {
            self.isCheckingAuth = false
        }
    }

    func signIn(username: String, password: String) async {
        // ✅ Prevent duplicate login attempts (fixes AuthError 5)
        guard !isAuthenticated else {
            print("🔐 [AUTH] User is already authenticated, skipping login")
            return
        }

        do {
            print("🔐 [AUTH] Attempting sign in for: \(username)")
            let result = try await Amplify.Auth.signIn(username: username, password: password)

            if result.isSignedIn {
                await checkAuthState() // Refresh auth state
                print("✅ [AUTH] Sign in successful")
            } else {
                print("⚠️ [AUTH] Sign in requires additional steps: \(result.nextStep)")
            }
        } catch {
            print("❌ [AUTH] Sign in failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() async {
        do {
            print("🔐 [AUTH] Signing out...")
            _ = try await Amplify.Auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.errorMessage = nil
            }
            print("✅ [AUTH] Sign out successful")
        } catch {
            print("❌ [AUTH] Sign out failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// 📱 Simple Login View
struct SimpleLoginView: View {
    @EnvironmentObject private var authService: SimpleAmplifyAuthService
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("CLARITY")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let error = authService.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button("Sign In") {
                        Task {
                            await authService.signIn(username: username, password: password)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Login")
        }
    }
}

// 📊 Simple Dashboard
struct SimpleDashboard: View {
    @EnvironmentObject private var authService: SimpleAmplifyAuthService

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Welcome to CLARITY")
                    .font(.title)
                    .fontWeight(.semibold)

                if let userId = authService.currentUser {
                    Text("Signed in as: \(userId)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Dashboard functionality will appear here")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Sign Out") {
                    Task {
                        await authService.signOut()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}
