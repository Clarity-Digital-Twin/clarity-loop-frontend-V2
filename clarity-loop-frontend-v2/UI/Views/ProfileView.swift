//
//  ProfileView.swift
//  clarity-loop-frontend-v2
//
//  User profile view with settings and account management
//

import SwiftUI
import ClarityDomain
import ClarityCore

public struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.authService) private var authService
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    VStack(alignment: .center, spacing: 16) {
                        // Profile Avatar
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                        
                        // User Name
                        Text(appState.currentUserName ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // Email
                        Text(appState.currentUserEmail ?? "user@example.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                
                // Account Details
                Section("Account Details") {
                    DetailRow(label: "Email", value: appState.currentUserEmail ?? "user@example.com")
                    DetailRow(label: "First Name", value: appState.currentUserName?.components(separatedBy: " ").first ?? "User")
                    DetailRow(label: "Last Name", value: appState.currentUserName?.components(separatedBy: " ").last ?? "")
                    
                    // TODO: Add date of birth when stored in AppState
                    
                    // TODO: Add phone number when stored in AppState
                    
                    DetailRow(label: "Member Since", value: "January 2025")
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink(destination: Text("Notifications Settings")) {
                        SettingsRow(
                            icon: "bell",
                            title: "Notifications",
                            color: .red
                        )
                    }
                    
                    NavigationLink(destination: Text("Privacy Settings")) {
                        SettingsRow(
                            icon: "lock",
                            title: "Privacy",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: Text("Health Data Sources")) {
                        SettingsRow(
                            icon: "heart.text.square",
                            title: "Health Sources",
                            color: .pink
                        )
                    }
                    
                    NavigationLink(destination: Text("Export Data")) {
                        SettingsRow(
                            icon: "square.and.arrow.up",
                            title: "Export Data",
                            color: .green
                        )
                    }
                }
                
                // Support Section
                Section("Support") {
                    NavigationLink(destination: Text("Help Center")) {
                        SettingsRow(
                            icon: "questionmark.circle",
                            title: "Help Center",
                            color: .orange
                        )
                    }
                    
                    NavigationLink(destination: Text("Terms of Service")) {
                        SettingsRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            color: .gray
                        )
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy")) {
                        SettingsRow(
                            icon: "shield",
                            title: "Privacy Policy",
                            color: .purple
                        )
                    }
                }
                
                // Danger Zone
                Section {
                    Button(action: { showingLogoutAlert = true }) {
                        HStack {
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                            }
                            
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isLoggingOut)
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func performLogout() {
        isLoggingOut = true
        
        Task {
            do {
                guard let authService else {
                    print("Error: AuthService not available")
                    isLoggingOut = false
                    return
                }
                
                try await authService.logout()
                
                await MainActor.run {
                    appState.logout()
                    isLoggingOut = false
                }
            } catch {
                await MainActor.run {
                    isLoggingOut = false
                    // In a real app, show an error alert
                    print("Logout failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}
