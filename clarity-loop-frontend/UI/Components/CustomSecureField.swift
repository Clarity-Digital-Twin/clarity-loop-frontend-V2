import SwiftUI

/// A custom SecureField component that works properly with @Observable bindings
/// and avoids AutoFill conflicts that cause yellow placeholder text.
struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .textContentType(.newPassword) // Disable AutoFill
            .autocorrectionDisabled(true)
    }
}

/// An enhanced SecureField with show/hide toggle for better UX
struct AutoFillCompatibleSecureField: View {
    @Binding var text: String
    let placeholder: String
    @State private var isSecured = true

    var body: some View {
        HStack {
            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                        .textContentType(.newPassword) // Force new password mode
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .autocorrectionDisabled()
                }
            }
            .textInputAutocapitalization(.never)

            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var password1 = ""
    @Previewable @State var password2 = ""

    VStack {
        CustomSecureField(text: $password1, placeholder: "Basic SecureField")
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

        AutoFillCompatibleSecureField(text: $password2, placeholder: "Enhanced SecureField")
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
}
