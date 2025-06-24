import SwiftUI

struct LoginView: View {
    // MARK: - Environment

    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel: LoginViewModel

    // MARK: - Initializer

    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                CustomSecureField(text: $viewModel.password, placeholder: "Password")
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button(action: {
                        Task {
                            await viewModel.login()
                        }
                    }) {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                NavigationLink(
                    "Don't have an account? Register",
                    destination: RegistrationView(authService: authService)
                )
            }
            .padding()
            .sheet(isPresented: $viewModel.shouldShowEmailVerification) {
                EmailVerificationView(
                    email: viewModel.email,
                    password: viewModel.password,
                    authService: authService
                )
            }
        }
    }
}

#Preview {
    // Create a preview-safe APIClient
    guard
        let previewAPIClient = APIClient(
            baseURLString: AppConfig.previewAPIBaseURL,
            tokenProvider: { nil }
        ) else {
        return Text("Failed to create preview client")
    }

    return LoginView(viewModel: LoginViewModel(authService: AuthService(apiClient: previewAPIClient)))
}
