//
//  LoginView.swift
//  clarity-loop-frontend-v2
//
//  Login screen with TDD-driven ViewModel
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @EnvironmentObject private var appState: AppState
    
    public init() {
        let container = DIContainer.shared
        let factory = container.require(LoginViewModelFactory.self)
        let loginUseCase = factory.create()
        
        self._viewModel = State(wrappedValue: LoginViewModel(loginUseCase: loginUseCase))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("CLARITY Pulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Health Companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your email", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(viewModel.viewState.isLoading)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter your password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .disabled(viewModel.viewState.isLoading)
                    }
                    
                    // Error Message
                    if case .error(let message) = viewModel.viewState {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }
                    
                    // Login Button
                    Button(action: { Task { await performLogin() } }) {
                        HStack {
                            if viewModel.viewState.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoginButtonEnabled ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.isLoginButtonEnabled)
                    
                    // Forgot Password
                    Button("Forgot Password?") {
                        // TODO: Implement forgot password
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    
                    Button("Sign Up") {
                        // TODO: Navigate to sign up
                    }
                    .foregroundColor(.accentColor)
                }
                .font(.footnote)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
        .onReceive(viewModel.$viewState) { state in
            if case .success(let user) = state {
                appState.login(with: user)
            }
        }
    }
    
    private func performLogin() async {
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Perform login
        await viewModel.login()
    }
}