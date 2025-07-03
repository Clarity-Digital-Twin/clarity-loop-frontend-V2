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
                    // Show working auth UI
                    ClarityAuthView()
        } else {
                    // Show configuration status with debugging
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("CLARITY Digital Twin")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(configurationStep)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if let error = amplifyError {
                            Text("Error: \(error.localizedDescription)")
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    .padding()
                }
            }
            .onAppear {
                configureAmplify()
            }
        }
    }

    private func configureAmplify() {
        print("🔧 [AMPLIFY] Starting configuration...")
        configurationStep = "Configuring Amplify..."

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            print("🔧 [AMPLIFY] Added Cognito plugin")
            configurationStep = "Added Cognito plugin..."

            try Amplify.configure()
            print("🔧 [AMPLIFY] Configuration completed successfully!")
            configurationStep = "Amplify configured successfully!"

            DispatchQueue.main.async {
                self.isAmplifyConfigured = true
            }

        } catch {
            print("❌ [AMPLIFY] Configuration failed: \(error)")
            configurationStep = "Configuration failed: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.amplifyError = error
            }
        }
    }
}

// MARK: - Auth View with Full Debug Logging
struct ClarityAuthView: View {
    @State private var currentUser: String = ""
    @State private var isSignedIn = false
    @State private var authStep = "Checking auth state..."
    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("CLARITY")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Digital Twin Platform")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // Auth Status
                VStack(spacing: 15) {
                    Text(authStep)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if isSignedIn {
                        VStack(spacing: 10) {
                            Text("✅ Successfully Authenticated")
                                .foregroundColor(.green)
                                .font(.headline)

                            Text("User: \(currentUser)")
                                .font(.body)
                                .foregroundColor(.secondary)

                            Button("Sign Out") {
                                signOut()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        VStack(spacing: 15) {
                            Button("Sign In") {
                                showSignIn = true
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.headline)

                            Button("Create Account") {
                                showSignUp = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                checkAuthState()
            }
            .sheet(isPresented: $showSignIn) {
                SignInView { success in
                    if success {
                        showSignIn = false
                        checkAuthState()
                    }
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView { success in
                    if success {
                        showSignUp = false
                        checkAuthState()
                    }
                }
            }
        }
    }

    private func checkAuthState() {
        print("🔐 [AUTH] Checking current auth state...")
        authStep = "Checking authentication..."

        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                print("🔐 [AUTH] Session fetched: \(session.isSignedIn)")

                if session.isSignedIn {
                    let user = try await Amplify.Auth.getCurrentUser()
                    print("🔐 [AUTH] Current user: \(user.username)")

                    DispatchQueue.main.async {
                        self.currentUser = user.username
                        self.isSignedIn = true
                        self.authStep = "Authentication verified!"
                    }
                } else {
                    print("🔐 [AUTH] No current session")
                    DispatchQueue.main.async {
                        self.isSignedIn = false
                        self.authStep = "Please sign in to continue"
                    }
                }
            } catch {
                print("❌ [AUTH] Error checking auth state: \(error)")
                DispatchQueue.main.async {
                    self.authStep = "Auth check failed: \(error.localizedDescription)"
                    self.isSignedIn = false
                }
            }
        }
    }

    private func signOut() {
        print("🔐 [AUTH] Starting sign out...")
        authStep = "Signing out..."

        Task {
            do {
                _ = try await Amplify.Auth.signOut()
                print("🔐 [AUTH] Sign out successful")

                DispatchQueue.main.async {
                    self.isSignedIn = false
                    self.currentUser = ""
                    self.authStep = "Signed out successfully"
                }
            } catch {
                print("❌ [AUTH] Sign out failed: \(error)")
                DispatchQueue.main.async {
                    self.authStep = "Sign out failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    let onSuccess: (Bool) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)

                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSuccess(false)
                    }
                }
            }
        }
    }

    private func signIn() {
        print("🔐 [SIGNIN] Attempting sign in for email: \(email)")
        isLoading = true
        errorMessage = ""

        Task {
            do {
                let result = try await Amplify.Auth.signIn(username: email, password: password)
                print("🔐 [SIGNIN] Sign in result: \(result)")

                if result.isSignedIn {
                    print("🔐 [SIGNIN] Successfully signed in!")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.onSuccess(true)
                    }
                } else {
                    print("🔐 [SIGNIN] Sign in incomplete, next step: \(result.nextStep)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Sign in incomplete: \(result.nextStep)"
                    }
                }
            } catch {
                print("❌ [SIGNIN] Sign in failed: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    let onSuccess: (Bool) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)

                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Button(action: signUp) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading || email.isEmpty || password.isEmpty || password != confirmPassword)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSuccess(false)
                    }
                }
            }
        }
    }

    private func signUp() {
        print("🔐 [SIGNUP] Attempting sign up for email: \(email)")
        isLoading = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                let result = try await Amplify.Auth.signUp(
                    username: email,
                    password: password,
                    options: AuthSignUpRequest.Options(userAttributes: [
                        AuthUserAttribute(.email, value: email)
                    ])
                )

                print("🔐 [SIGNUP] Sign up result: \(result)")

                DispatchQueue.main.async {
                    self.isLoading = false

                    if result.isSignUpComplete {
                        self.successMessage = "Account created successfully!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.onSuccess(true)
                        }
                    } else {
                        self.successMessage = "Please check your email for verification code"
                    }
                }
            } catch {
                print("❌ [SIGNUP] Sign up failed: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    }
                }
        }
    }
}
