//
//  LoginViewModel.swift
//  clarity-loop-frontend-v2
//
//  ViewModel for login screen following MVVM pattern
//

import Foundation
import ClarityDomain
import ClarityData

@MainActor
@Observable
public final class LoginViewModel {
    
    // MARK: - Published Properties
    
    public private(set) var viewState: ViewState<User> = .idle
    public var email: String = ""
    public var password: String = ""
    
    // MARK: - Computed Properties
    
    public var isLoginButtonEnabled: Bool {
        isValidEmail(email) && !password.isEmpty && !viewState.isLoading
    }
    
    // MARK: - Dependencies
    
    private let loginUseCase: LoginUseCaseProtocol
    
    // MARK: - Initialization
    
    public init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }
    
    // MARK: - Public Methods
    
    public func login() async {
        guard isLoginButtonEnabled else { return }
        
        viewState = .loading
        
        do {
            let user = try await loginUseCase.execute(
                email: email,
                password: password
            )
            viewState = .success(user)
            
            // Clear sensitive data
            password = ""
            
        } catch let error as NetworkError {
            viewState = .error(error.localizedDescription)
        } catch let error as AuthError {
            viewState = .error(error.localizedDescription)
        } catch {
            viewState = .error("An unexpected error occurred")
        }
    }
    
    public func clearError() {
        if case .error = viewState {
            viewState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}