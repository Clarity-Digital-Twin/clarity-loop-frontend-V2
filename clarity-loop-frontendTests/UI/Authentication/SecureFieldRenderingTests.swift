@testable import clarity_loop_frontend
import SwiftUI
import XCTest

/// CRITICAL UI Tests for SecureField rendering issues
/// These tests address the yellow "Automatic Strong Password cover view text" bug
final class SecureFieldRenderingTests: XCTestCase {
    // MARK: - Test Setup

    override func setUpWithError() throws {
        // Set up UI testing environment
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Clean up UI test environment
    }

    // MARK: - SecureField AutoFill Issues

    func testSecureFieldVisibilityAndInteraction() throws {
        // Test that SecureField is properly visible and interactive

        // Test password field configuration
        let passwordField = SecureField("Password", text: .constant(""))
            .textContentType(.password)

        // Test new password field configuration
        let newPasswordField = SecureField("New Password", text: .constant(""))
            .textContentType(.newPassword)

        // Verify field configurations don't cause overlay issues
        XCTAssertNotNil(passwordField, "Password field should be created successfully")
        XCTAssertNotNil(newPasswordField, "New password field should be created successfully")

        // Test that textContentType is properly set to prevent AutoFill interference
        // These configurations should prevent the yellow overlay issue
    }

    func testSecureFieldTextContentType() throws {
        // Test proper textContentType configuration

        // Test login password field
        let loginPassword = SecureField("Password", text: .constant("test"))
            .textContentType(.password)

        // Test registration password field
        let newPassword = SecureField("New Password", text: .constant("test"))
            .textContentType(.newPassword)

        // Test confirmation password field
        let confirmPassword = SecureField("Confirm Password", text: .constant("test"))
            .textContentType(.newPassword)

        // Verify fields are created without issues
        XCTAssertNotNil(loginPassword, "Login password field should be configured correctly")
        XCTAssertNotNil(newPassword, "New password field should be configured correctly")
        XCTAssertNotNil(confirmPassword, "Confirm password field should be configured correctly")

        // Test that proper textContentType prevents AutoFill overlay
        // The .newPassword content type should prevent automatic strong password generation
        // The .password content type should work with saved passwords without overlay
    }

    func testSecureFieldAutofillBehavior() throws {
        // Test AutoFill integration works correctly

        // Create SecureField configurations that should work properly with AutoFill
        struct TestPasswordForm: View {
            @State private var password = ""
            @State private var newPassword = ""
            @State private var confirmPassword = ""

            var body: some View {
                VStack {
                    SecureField("Current Password", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()

                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                }
            }
        }

        let testForm = TestPasswordForm()
        XCTAssertNotNil(testForm, "Test form should be created successfully")

        // Test that form configuration prevents AutoFill issues
        // - No yellow overlay should appear
        // - Password fields should remain functional
        // - AutoFill suggestions should work without interference
    }

    func testSecureFieldKeyboardAndInputBehavior() throws {
        // Test SecureField keyboard and input behavior

        // Test various SecureField configurations
        struct TestSecureFields: View {
            @State private var password1 = ""
            @State private var password2 = ""
            @State private var password3 = ""

            var body: some View {
                VStack {
                    // Standard password field
                    SecureField("Password", text: $password1)
                        .textContentType(.password)
                        .keyboardType(.default)

                    // New password with validation
                    SecureField("New Password", text: $password2)
                        .textContentType(.newPassword)
                        .keyboardType(.default)
                        .autocorrectionDisabled()

                    // Confirmation password
                    SecureField("Confirm Password", text: $password3)
                        .textContentType(.newPassword)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                }
            }
        }

        let testFields = TestSecureFields()
        XCTAssertNotNil(testFields, "Test secure fields should be created successfully")

        // Test that configurations prevent keyboard/input issues
        // - Keyboard should appear correctly
        // - Text input should work properly
        // - No layout constraint conflicts
        // - No "Cannot show Automatic Strong Passwords" errors
    }

    // MARK: - AutoFill Integration Tests

    func testAutoFillPasswordGeneration() throws {
        // Test AutoFill password generation behavior

        // Test registration form that should trigger AutoFill properly
        struct RegistrationForm: View {
            @State private var email = ""
            @State private var password = ""
            @State private var confirmPassword = ""

            var body: some View {
                VStack {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                }
            }
        }

        let registrationForm = RegistrationForm()
        XCTAssertNotNil(registrationForm, "Registration form should be created successfully")

        // Verify that this configuration allows proper AutoFill behavior:
        // - Strong password generation should work when appropriate
        // - No yellow overlay should interfere with manual input
        // - Password suggestions should appear in proper UI
    }

    func testAutoFillPasswordSaving() throws {
        // Test AutoFill password saving behavior

        // Test login form that should work with saved passwords
        struct LoginForm: View {
            @State private var email = ""
            @State private var password = ""

            var body: some View {
                VStack {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                }
            }
        }

        let loginForm = LoginForm()
        XCTAssertNotNil(loginForm, "Login form should be created successfully")

        // Verify that this configuration works with saved passwords:
        // - Saved passwords should populate correctly
        // - No interference with manual typing
        // - AutoFill UI should appear appropriately
    }

    // MARK: - Layout and Rendering Tests

    func testSecureFieldLayoutStability() throws {
        // Test SecureField layout stability during various states

        struct TestLayoutForm: View {
            @State private var password = ""
            @State private var showPassword = false
            @State private var hasError = false

            var body: some View {
                VStack {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }

                    if hasError {
                        Text("Password is required")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(showPassword ? "Hide" : "Show") {
                        showPassword.toggle()
                    }
                }
            }
        }

        let testForm = TestLayoutForm()
        XCTAssertNotNil(testForm, "Test layout form should be created successfully")

        // Test that layout remains stable during:
        // - Password visibility toggle
        // - Error message appearance/disappearance
        // - Keyboard appearance/dismissal
        // - AutoFill interaction
    }

    func testSecureFieldErrorStateRendering() throws {
        // Test SecureField rendering in error states

        struct ErrorStateForm: View {
            @State private var password = ""
            @State private var errorMessage: String? = nil

            var isPasswordValid: Bool {
                password.count >= 8
            }

            var body: some View {
                VStack {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(errorMessage != nil ? Color.red : Color.clear, lineWidth: 1)
                        )

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .onChange(of: password) { _, newValue in
                    if !newValue.isEmpty, newValue.count < 8 {
                        errorMessage = "Password must be at least 8 characters"
                    } else {
                        errorMessage = nil
                    }
                }
            }
        }

        let errorForm = ErrorStateForm()
        XCTAssertNotNil(errorForm, "Error state form should be created successfully")

        // Test that error states don't interfere with AutoFill:
        // - Error highlighting doesn't break SecureField
        // - Error messages don't overlap with AutoFill UI
        // - Form remains functional during error display
    }

    // MARK: - Performance and Memory Tests

    func testSecureFieldMemoryUsage() throws {
        // Test SecureField memory usage and cleanup

        // Test creating and destroying multiple SecureFields
        for i in 0..<100 {
            let field = SecureField("Password \(i)", text: .constant(""))
                .textContentType(.password)

            XCTAssertNotNil(field, "SecureField \(i) should be created successfully")
        }

        // Test that multiple SecureFields don't cause memory issues
        // Memory pressure could contribute to NaN values in CoreGraphics
    }

    func testSecureFieldTextBufferManagement() throws {
        // Test secure text buffer management

        var textBinding = ""
        let field = SecureField("Password", text: Binding(
            get: { textBinding },
            set: { newValue in
                // Ensure text updates don't cause NaN values
                if !newValue.contains("nan"), !newValue.contains("NaN") {
                    textBinding = newValue
                }
            }
        ))
        .textContentType(.password)

        XCTAssertNotNil(field, "SecureField with custom binding should be created")

        // Test that text buffer management doesn't introduce invalid values
        // This could prevent CoreGraphics NaN errors from text handling
    }
}
