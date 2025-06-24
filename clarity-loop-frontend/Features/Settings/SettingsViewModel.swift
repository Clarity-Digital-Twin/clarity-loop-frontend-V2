import Foundation
import Observation

@Observable
final class SettingsViewModel {
    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol
    private let healthKitService: any HealthKitServiceProtocol

    // MARK: - State Properties

    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var showingSignOutAlert = false
    var showingDeleteAccountAlert = false

    // Profile editing state
    var isEditingProfile = false
    var firstName = ""
    var lastName = ""
    var email = ""

    // App preferences
    var notificationsEnabled = true
    var biometricAuthEnabled = false
    var dataExportEnabled = true
    var analyticsEnabled = false

    // Health data settings
    var healthKitAuthorizationStatus = "Unknown"
    var lastSyncDate: Date?
    var autoSyncEnabled = true
    
    // User profile state
    var currentUser = ""
    var userName = ""
    var userEmail = ""
    var isLoadingUser = true
    
    // Computed properties for UI
    var userInitials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            let firstInitial = components[0].prefix(1).uppercased()
            let lastInitial = components[1].prefix(1).uppercased()
            return "\(firstInitial)\(lastInitial)"
        } else if !userName.isEmpty {
            return String(userName.prefix(2)).uppercased()
        } else {
            return "U"
        }
    }
    
    var userVerified: Bool {
        // Check if we have a current user from auth service
        return currentUser != "Not logged in" && !userEmail.isEmpty
    }

    var hasUnsavedChanges: Bool {
        // Check if any profile fields have been modified
        isEditingProfile && (!firstName.isEmpty || !lastName.isEmpty)
    }

    // MARK: - Initializer

    init(authService: any AuthServiceProtocol, healthKitService: any HealthKitServiceProtocol) {
        self.authService = authService
        self.healthKitService = healthKitService
        checkHealthKitStatus()
        // Load user profile asynchronously after initialization
        Task {
            await loadUserProfile()
        }
    }

    // MARK: - Profile Management

    func loadUserProfile() async {
        isLoadingUser = true
        
        // Load user profile data from Cognito
        if let user = await authService.currentUser {
            await MainActor.run {
                self.currentUser = user.email
                self.userName = user.fullName ?? user.email
                self.userEmail = user.email
                self.email = user.email
                
                // Parse name if available
                if let fullName = user.fullName {
                    let names = fullName.split(separator: " ")
                    self.firstName = String(names.first ?? "")
                    self.lastName = names.dropFirst().joined(separator: " ")
                }
                
                self.isLoadingUser = false
            }
        } else {
            await MainActor.run {
                self.currentUser = "Not logged in"
                self.userName = "Guest"
                self.userEmail = ""
                self.isLoadingUser = false
            }
        }
    }

    func startEditingProfile() async {
        isEditingProfile = true
        // Pre-populate fields with current values
        await loadUserProfile()
    }

    func cancelEditingProfile() {
        isEditingProfile = false
        firstName = ""
        lastName = ""
        errorMessage = nil
    }

    func saveProfile() async {
        guard !firstName.isEmpty || !lastName.isEmpty else {
            errorMessage = "Please enter at least a first or last name"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // In a real app, you'd call your backend API to update profile
            // For now, we'll simulate a successful update
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            successMessage = "Profile updated successfully"
            isEditingProfile = false
            firstName = ""
            lastName = ""
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - HealthKit Management

    func checkHealthKitStatus() {
        if healthKitService.isHealthDataAvailable() {
            healthKitAuthorizationStatus = "Available"
        } else {
            healthKitAuthorizationStatus = "Not Available"
        }
    }

    func requestHealthKitAuthorization() async {
        isLoading = true
        errorMessage = nil

        do {
            try await healthKitService.requestAuthorization()
            healthKitAuthorizationStatus = "Authorized"
            successMessage = "HealthKit authorization granted"
            
            // 🔥 CRITICAL FIX: Setup background delivery immediately after authorization
            try await healthKitService.enableBackgroundDelivery()
            healthKitService.setupObserverQueries()
            print("✅ HealthKit background sync enabled from Settings")
            
        } catch {
            errorMessage = "Failed to authorize HealthKit: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func syncHealthData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get current user
            guard let currentUser = await authService.currentUser else {
                errorMessage = "Please log in to sync health data"
                isLoading = false
                return
            }
            
            // Get date range for sync (last 7 days)
            let endDate = Date()
            let startDate = lastSyncDate ?? Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            // Fetch health data from HealthKit
            let uploadRequest = try await healthKitService.fetchHealthDataForUpload(
                from: startDate,
                to: endDate,
                userId: currentUser.id
            )
            
            // Check if there's data to upload
            if uploadRequest.samples.isEmpty {
                successMessage = "No new health data to sync"
                lastSyncDate = endDate
                isLoading = false
                return
            }
            
            // Upload the data
            let response = try await healthKitService.uploadHealthKitData(uploadRequest)
            
            if response.success {
                lastSyncDate = endDate
                successMessage = "Synced \(response.processedSamples) health samples"
                
                // Post notification for dashboard refresh
                NotificationCenter.default.post(name: .healthDataSynced, object: nil)
            } else {
                errorMessage = response.message ?? "Failed to sync health data"
            }
            
        } catch {
            errorMessage = "Failed to sync health data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Data Management

    func exportUserData() async {
        isLoading = true
        errorMessage = nil

        do {
            // In a real app, you'd generate and export user data
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
            successMessage = "Data export initiated. You'll receive an email when ready."
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteAllUserData() async {
        isLoading = true
        errorMessage = nil

        do {
            // In a real app, you'd call your backend to delete all user data
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            successMessage = "All user data has been deleted"
        } catch {
            errorMessage = "Failed to delete user data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Authentication Actions

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async {
        isLoading = true
        errorMessage = nil

        do {
            // In a real app, you'd call your backend to delete the account
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay

            // Then sign out
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Utility Methods

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        // In a real app, you'd save this preference
    }

    func toggleBiometricAuth() {
        biometricAuthEnabled.toggle()
        // In a real app, you'd save this preference and configure biometric auth
    }

    func toggleAutoSync() {
        autoSyncEnabled.toggle()
        // In a real app, you'd save this preference and configure auto sync
    }

    func toggleAnalytics() {
        analyticsEnabled.toggle()
        // In a real app, you'd save this preference and configure analytics
    }
}
