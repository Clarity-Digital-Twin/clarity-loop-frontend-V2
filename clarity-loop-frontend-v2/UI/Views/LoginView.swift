//
//  LoginView.swift
//  clarity-loop-frontend-v2
//
//  Login screen with TDD-driven ViewModel
//

import SwiftUI
import ClarityDomain
import ClarityCore
import ClarityData // For ErrorHandler access

public struct LoginView: View {
    @Environment(\.loginViewModelFactory) private var factory
    @State private var viewModel: LoginViewModel?

    public init() {
        // NO WORK IN INIT - dependencies resolved in .task
    }

    public var body: some View {
        VStack {
            if let viewModel {
                LoginContentView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
            }
        }
        .task {
            // Initialize viewModel from factory
            print("🔍 LoginView.task - creating viewModel...")
            let loginUseCase = factory.create()
            viewModel = LoginViewModel(loginUseCase: loginUseCase)
            print("✅ LoginView viewModel created successfully")
        }
    }
}

// Separate view that actually uses the viewModel
private struct LoginContentView: View {
    @Bindable var viewModel: LoginViewModel
    @Environment(AppState.self) private var appState
    @FocusState private var focusedField: Field?
    @State private var showingError = false
    @State private var errorPresentation: ErrorPresentation?

    var body: some View {
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
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .disabled(viewModel.viewState.isLoading)
                            .focused($focusedField, equals: Field.email)
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SecureField("Enter your password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.viewState.isLoading)
                            .focused($focusedField, equals: Field.password)
                    }

                    // Error Message
                    if case .error(let message) = viewModel.viewState {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)

                            Text(message.localizedDescription)
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
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .onChange(of: viewModel.viewState) { _, newState in
            switch newState {
            case .success(let user):
                appState.login(
                    userId: user.id,
                    email: user.email,
                    name: "\(user.firstName) \(user.lastName)"
                )
            case .error(let error):
                if let appError = error as? ClarityDomain.AppError {
                    Task { @MainActor in
                        let errorHandler = ErrorHandler(
                            logger: ConsoleLogger(),
                            analytics: NoOpAnalytics()
                        )
                        errorPresentation = await errorHandler.presentToUser(appError)
                        showingError = true
                    }
                }
            default:
                break
            }
        }
        .alert(
            errorPresentation?.title ?? "Error",
            isPresented: $showingError,
            presenting: errorPresentation
        ) { presentation in
            ForEach(presentation.actions.indices, id: \.self) { index in
                let action = presentation.actions[index]
                Button(action.title) {
                    if let handler = action.handler {
                        Task {
                            await handler()
                        }
                    }
                    viewModel.clearError()
                }
            }
        } message: { presentation in
            Text(presentation.message)
        }
    }

    private func performLogin() async {
        // Hide keyboard
        focusedField = nil

        // Perform login
        await viewModel.login()
    }
}

// MARK: - Field Enum

private enum Field: Hashable {
    case email
    case password
}
