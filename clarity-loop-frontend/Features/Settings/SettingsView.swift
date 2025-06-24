import SwiftUI

struct SettingsView: View {
    @Environment(\.authService) private var authService
    @Environment(\.healthKitService) private var healthKitService
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                SettingsContentView(viewModel: viewModel)
            } else {
                LoadingView(
                    message: "Loading settings...",
                    style: .fullScreen
                )
                .onAppear {
                    viewModel = SettingsViewModel(
                        authService: authService,
                        healthKitService: healthKitService
                    )
                }
            }
        }
    }
}

struct SettingsContentView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            // Profile Section
            Section("Profile") {
                if viewModel.isEditingProfile {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("First Name", text: $viewModel.firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Last Name", text: $viewModel.lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        HStack {
                            Button("Cancel") {
                                viewModel.cancelEditingProfile()
                            }
                            .foregroundColor(.secondary)

                            Spacer()

                            Button("Save") {
                                Task {
                                    await viewModel.saveProfile()
                                }
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                } else if viewModel.isLoadingUser {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading profile...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 16) {
                        // Profile Avatar
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Text(viewModel.userInitials)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.userName)
                                .font(.headline)
                            Text(viewModel.userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if viewModel.userVerified {
                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await viewModel.startEditingProfile()
                        }
                    }
                }
            }

            // Health Data Section
            Section("Health Data") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HealthKit Status:")
                        Spacer()
                        Text(viewModel.healthKitAuthorizationStatus)
                            .foregroundColor(.secondary)
                    }

                    if let lastSync = viewModel.lastSyncDate {
                        HStack {
                            Text("Last Sync:")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle("Auto Sync", isOn: Binding(
                    get: { viewModel.autoSyncEnabled },
                    set: { _ in viewModel.toggleAutoSync() }
                ))
                
                if !viewModel.autoSyncEnabled {
                    Button("Sync Now") {
                        Task {
                            await viewModel.syncHealthData()
                        }
                    }
                    .font(.callout)
                    .disabled(viewModel.isLoading)
                }
                
                if viewModel.healthKitAuthorizationStatus != "Authorized" {
                    Button("Grant HealthKit Access") {
                        Task {
                            await viewModel.requestHealthKitAuthorization()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            // App Preferences Section
            Section("Preferences") {
                Toggle("Notifications", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { _ in viewModel.toggleNotifications() }
                ))

                Toggle("Biometric Authentication", isOn: Binding(
                    get: { viewModel.biometricAuthEnabled },
                    set: { _ in viewModel.toggleBiometricAuth() }
                ))

                Toggle("Analytics", isOn: Binding(
                    get: { viewModel.analyticsEnabled },
                    set: { _ in viewModel.toggleAnalytics() }
                ))
            }

            // Data Management Section
            Section("Data Management") {
                Button("Export My Data") {
                    Task {
                        await viewModel.exportUserData()
                    }
                }
                .disabled(viewModel.isLoading)

                Button("Delete All My Data") {
                    Task {
                        await viewModel.deleteAllUserData()
                    }
                }
                .foregroundColor(.red)
                .disabled(viewModel.isLoading)
            }

            // Account Section
            Section("Account") {
                Button("Sign Out") {
                    viewModel.showingSignOutAlert = true
                }
                .foregroundColor(.red)

                Button("Delete Account") {
                    viewModel.showingDeleteAccountAlert = true
                }
                .foregroundColor(.red)
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Settings")
        .overlay {
            if viewModel.isLoading {
                LoadingView(
                    message: nil,
                    style: .overlay
                )
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            if let message = viewModel.successMessage {
                Text(message)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert("Sign Out", isPresented: $viewModel.showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $viewModel.showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
}

#if DEBUG
    #Preview {
        guard
            let previewAPIClient = APIClient(
                baseURLString: AppConfig.previewAPIBaseURL,
                tokenProvider: { nil }
            ) else {
            return Text("Failed to create preview client")
        }

        return SettingsView()
            .environment(\.authService, AuthService(apiClient: previewAPIClient))
            .environment(\.healthKitService, HealthKitService(apiClient: previewAPIClient))
    }
#endif
