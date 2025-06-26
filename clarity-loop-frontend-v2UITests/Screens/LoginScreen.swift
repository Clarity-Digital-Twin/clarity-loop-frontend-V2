//
//  LoginScreen.swift
//  clarity-loop-frontend-v2UITests
//
//  Screen object pattern implementation for Login screen
//

import XCTest

/// Screen object representing the Login screen
@MainActor
final class LoginScreen {
    
    private let app: XCUIApplication
    
    // MARK: - Elements
    
    var emailTextField: XCUIElement {
        app.textFields["email_textfield"]
    }
    
    var passwordSecureField: XCUIElement {
        app.secureTextFields["password_securefield"]
    }
    
    var loginButton: XCUIElement {
        app.buttons["login_button"]
    }
    
    var forgotPasswordButton: XCUIElement {
        app.buttons["forgot_password_button"]
    }
    
    var signUpButton: XCUIElement {
        app.buttons["signup_button"]
    }
    
    var errorLabel: XCUIElement {
        app.staticTexts["error_label"]
    }
    
    var loadingIndicator: XCUIElement {
        app.activityIndicators["loading_indicator"]
    }
    
    // MARK: - Initialization
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - Actions
    
    /// Enter email in the email text field
    func enterEmail(_ email: String) {
        emailTextField.tap()
        emailTextField.typeText(email)
    }
    
    /// Enter password in the password secure field
    func enterPassword(_ password: String) {
        passwordSecureField.tap()
        passwordSecureField.typeText(password)
    }
    
    /// Tap the login button
    func tapLogin() {
        loginButton.tap()
    }
    
    /// Perform complete login action
    func login(email: String, password: String) {
        enterEmail(email)
        enterPassword(password)
        tapLogin()
    }
    
    /// Tap forgot password button
    func tapForgotPassword() {
        forgotPasswordButton.tap()
    }
    
    /// Tap sign up button
    func tapSignUp() {
        signUpButton.tap()
    }
    
    // MARK: - Assertions
    
    /// Check if login screen is displayed
    func isDisplayed() -> Bool {
        return emailTextField.exists && passwordSecureField.exists && loginButton.exists
    }
    
    /// Check if error message is displayed
    func isErrorDisplayed() -> Bool {
        return errorLabel.exists
    }
    
    /// Get error message text
    func getErrorMessage() -> String? {
        return errorLabel.exists ? errorLabel.label : nil
    }
    
    /// Check if loading indicator is displayed
    func isLoading() -> Bool {
        return loadingIndicator.exists
    }
    
    /// Wait for login screen to appear
    @discardableResult
    func waitForDisplay(timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: loginButton
        )
        
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        )
        
        return result == .completed
    }
    
    /// Wait for loading to complete
    @discardableResult
    func waitForLoadingToComplete(timeout: TimeInterval = 30) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: loadingIndicator
        )
        
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        )
        
        return result == .completed
    }
}