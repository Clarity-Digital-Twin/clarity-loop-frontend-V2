import SwiftUI

struct EmailVerificationView: View {
    @StateObject private var viewModel: EmailVerificationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedIndex: Int?

    init(email: String, password: String, authService: AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: EmailVerificationViewModel(
            email: email,
            password: password,
            authService: authService
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)

                    Text("Verify Your Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("We've sent a verification code to:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.email)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)

                // OTP Input
                VStack(spacing: 24) {
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            OTPDigitField(
                                digit: $viewModel.otpDigits[index],
                                index: index,
                                focusedIndex: $focusedIndex,
                                isError: viewModel.hasError
                            )
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.hasError)

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                }

                // Actions
                VStack(spacing: 16) {
                    Button(action: { Task { await viewModel.verifyCode() } }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text("Verify")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(viewModel.isVerifyButtonEnabled ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isVerifyButtonEnabled || viewModel.isLoading)

                    Button(action: { Task { await viewModel.resendCode() } }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Resend Code")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .disabled(viewModel.isLoading || viewModel.resendCooldown > 0)
                    .opacity(viewModel.resendCooldown > 0 ? 0.5 : 1.0)

                    if viewModel.resendCooldown > 0 {
                        Text("Resend available in \(viewModel.resendCooldown)s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedIndex = 0
                viewModel.startResendTimer()
            }
            .onChange(of: viewModel.isVerified) { _, isVerified in
                if isVerified {
                    // Navigate to home or dismiss based on your app flow
                    dismiss()
                }
            }
        }
    }
}

struct OTPDigitField: View {
    @Binding var digit: String
    let index: Int
    @FocusState.Binding var focusedIndex: Int?
    let isError: Bool

    var body: some View {
        TextField("", text: Binding(
            get: { digit },
            set: { newValue in
                // Only allow single digit
                if newValue.count <= 1, newValue.allSatisfy(\.isNumber) {
                    digit = newValue

                    // Auto-advance focus
                    if !newValue.isEmpty, index < 5 {
                        focusedIndex = index + 1
                    }
                } else if newValue.isEmpty {
                    digit = ""
                    // Move focus back on delete
                    if index > 0 {
                        focusedIndex = index - 1
                    }
                }
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(.title)
        .fontWeight(.semibold)
        .frame(width: 50, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(strokeColor, lineWidth: 2)
                )
        )
        .focused($focusedIndex, equals: index)
        .onTapGesture {
            focusedIndex = index
        }
        .modifier(ShakeEffect(animatableData: isError ? 1 : 0))
    }

    private var strokeColor: Color {
        if isError {
            .red
        } else if focusedIndex == index {
            .blue
        } else if !digit.isEmpty {
            .blue.opacity(0.3)
        } else {
            .clear
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 2) * 5, y: 0))
    }
}

#Preview {
    guard
        let previewAPIClient = APIClient(
            baseURLString: AppConfig.previewAPIBaseURL,
            tokenProvider: { nil }
        ) else {
        return Text("Failed to create preview client")
    }

    return EmailVerificationView(
        email: "test@example.com",
        password: "TestPass123!",
        authService: AuthService(apiClient: previewAPIClient)
    )
}
