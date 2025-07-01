//
//  LoginView.swift
//  ClarityUI
//
//  Minimal login view to establish baseline functionality
//

import SwiftUI
import ClarityCore
import ClarityDomain

public struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    public init() {
        print("🟡 LoginView initialized")
    }
    
    public var body: some View {
        ZStack {
            // Background color to ensure visibility
            Color.blue.opacity(0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("🧪 DEBUG: LoginView Rendering")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("CLARITY Login")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: performLogin) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }
                .padding(.horizontal, 40)
                
                // Debug info
                Text("App State: \(appState.isAuthenticated ? "Authenticated" : "Not Authenticated")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .onAppear {
            print("✅ LoginView appeared - UI should be visible")
        }
    }
    
    private func performLogin() {
        print("🔐 Login button tapped")
        isLoading = true
        errorMessage = nil
        
        // For now, just simulate a login
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            
            if username.lowercased() == "test" && password == "test" {
                print("✅ Login successful")
                appState.isAuthenticated = true
                appState.currentUser = User(id: "1", username: username, email: "\(username)@example.com")
            } else {
                print("❌ Login failed")
                errorMessage = "Invalid credentials. Try username: test, password: test"
            }
            
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}