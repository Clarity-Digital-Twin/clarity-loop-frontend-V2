//
//  LoginView.swift
//  clarity-loop-frontend-v2
//
//  Clean SwiftUI login view following MV pattern - no ViewModels
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct LoginView: View {
    @Environment(\.authenticationService) private var authService
    @Environment(AppState.self) private var appState
    
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    
    // For backwards compatibility with existing initializer
    private let dependencies: Dependencies?
    
    public init(dependencies: Dependencies? = nil) {
        self.dependencies = dependencies
    }
    
    private enum Field {
        case email, password
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    logoHeader
                    loginForm
                    Spacer(minLength: 40)
                    signUpLink
                }
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemBackground))
            .ignoresSafeArea(.keyboard)
        }
        .alert("Login Failed", isPresented: .constant(authService?.error != nil)) {
            Button("OK") {
                authService?.clearError()
            }
        } message: {
            if let error = authService?.error {
                Text(error.localizedDescription)
            }
        }
        .onChange(of: authService?.isAuthenticated ?? false) { _, isAuthenticated in
            // Handle authentication state changes
            if isAuthenticated, 
               let authService = authService,
               let user = authService.currentUser {
                // Update app state
                appState.login(
                    userId: user.id,
                    email: user.email,
                    name: "\(user.firstName) \(user.lastName)"
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var logoHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.multicolor)
            
            VStack(spacing: 8) {
                Text("CLARITY Pulse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your Health Companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 60)
    }
    
    private var loginForm: some View {
        VStack(spacing: 20) {
            emailField
            passwordField
            loginButton
            forgotPasswordButton
        }
        .padding(.horizontal, 32)
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("Enter your email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .disabled(authService?.isLoading ?? false)
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            SecureField("Enter your password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .disabled(authService?.isLoading ?? false)
                .onSubmit {
                    if canLogin {
                        Task {
                            await performLogin()
                        }
                    }
                }
        }
    }
    
    private var loginButton: some View {
        Button(action: {
            Task {
                await performLogin()
            }
        }) {
            Group {
                if authService?.isLoading ?? false {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canLogin ? Color.accentColor : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canLogin || (authService?.isLoading ?? false))
    }
    
    private var forgotPasswordButton: some View {
        Button("Forgot Password?") {
            // TODO: Implement forgot password
        }
        .font(.subheadline)
        .foregroundStyle(.tint)
    }
    
    private var signUpLink: some View {
        HStack {
            Text("Don't have an account?")
                .foregroundStyle(.secondary)
            
            Button("Sign Up") {
                // TODO: Navigate to sign up
            }
            .fontWeight(.medium)
            .foregroundStyle(.tint)
        }
        .font(.subheadline)
    }
    
    // MARK: - Private Properties
    
    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    // MARK: - Private Methods
    
    private func performLogin() async {
        // Dismiss keyboard
        focusedField = nil
        
        // Perform login
        guard let authService else {
            print("❌ AuthenticationService not available")
            return
        }
        
        await authService.login(email: email, password: password)
    }
}