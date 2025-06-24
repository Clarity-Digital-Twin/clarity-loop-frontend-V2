import Foundation
import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class UserProfileViewModel: BaseViewModel {
    // MARK: - Properties

    private(set) var profileState: ViewState<UserProfileModel> = .idle
    private(set) var updateState: ViewState<Bool> = .idle
    private(set) var imageSelection: PhotosPickerItem?
    private(set) var selectedImage: UIImage?

    // MARK: - Dependencies

    private let userProfileRepository: any UserProfileRepositoryProtocol
    private let authService: AuthServiceProtocol
    private let apiClient: APIClientProtocol

    // MARK: - Computed Properties

    var profile: UserProfileModel? {
        profileState.value
    }

    var isProfileComplete: Bool {
        guard let profile else { return false }
        return !(profile.displayName?.isEmpty ?? true) &&
            profile.dateOfBirth != nil &&
            profile.heightInCentimeters != nil &&
            profile.weightInKilograms != nil
    }

    var profileCompletionPercentage: Double {
        guard let profile else { return 0 }

        var completedFields = 0
        let totalFields = 5

        if !(profile.displayName?.isEmpty ?? true) { completedFields += 1 }
        if profile.dateOfBirth != nil { completedFields += 1 }
        if profile.heightInCentimeters != nil { completedFields += 1 }
        if profile.weightInKilograms != nil { completedFields += 1 }
        if profile.privacySettings?.shareHealthData ?? false { completedFields += 1 }

        return Double(completedFields) / Double(totalFields)
    }

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        userProfileRepository: any UserProfileRepositoryProtocol,
        authService: AuthServiceProtocol,
        apiClient: APIClientProtocol
    ) {
        self.userProfileRepository = userProfileRepository
        self.authService = authService
        self.apiClient = apiClient
        super.init(modelContext: modelContext)
    }

    // MARK: - Public Methods

    func loadProfile() async {
        profileState = .loading

        do {
            // Try to load from local storage first
            if let userId = await authService.currentUser?.id {
                let descriptor = FetchDescriptor<UserProfileModel>(
                    predicate: #Predicate { $0.userID == userId }
                )
                let results = try await userProfileRepository.fetch(descriptor: descriptor)
                if let localProfile = results.first {
                    profileState = .loaded(localProfile)

                    // Sync with backend in background
                    Task {
                        await syncProfile()
                    }
                } else {
                    // No local profile, fetch from backend
                    await fetchProfileFromBackend()
                }
            } else {
                // No user ID available
                profileState = .error(ProfileError.notAuthenticated)
            }
        } catch {
            profileState = .error(error)
            handle(error: error)
        }
    }

    func updateProfile(
        displayName: String? = nil,
        dateOfBirth: Date? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        activityLevel: ActivityLevel? = nil,
        healthGoals: String? = nil,
        medicalConditions: String? = nil
    ) async {
        guard let profile else { return }

        updateState = .loading

        // Update fields
        if let displayName { profile.displayName = displayName }
        if let dateOfBirth { profile.dateOfBirth = dateOfBirth }
        if let heightCm { profile.heightInCentimeters = heightCm }
        if let weightKg { profile.weightInKilograms = weightKg }
        // Activity level and health goals would be set in preferences
        // This would need proper mapping based on your app's needs

        do {
            // Save locally
            try await userProfileRepository.update(profile)
            profileState = .loaded(profile)

            // Sync with backend
            try await syncProfileUpdate(profile)
            updateState = .loaded(true)
        } catch {
            updateState = .error(error)
            handle(error: error)
        }
    }

    func updateProfileImage() async {
        guard let imageSelection else { return }

        do {
            if
                let data = try await imageSelection.loadTransferable(type: Data.self),
                let image = UIImage(data: data) {
                selectedImage = image

                // TODO: Upload image to storage service
                // For now, we'll just store it locally
                if let profile {
                    // Update lastSync as a proxy for update time
                    profile.lastSync = Date()
                    try await userProfileRepository.update(profile)
                    profileState = .loaded(profile)
                }
            }
        } catch {
            handle(error: error)
        }
    }

    func deleteAccount() async {
        guard let profile else { return }

        do {
            // Delete from backend first
            // TODO: Implement account deletion API

            // Delete local data
            try await userProfileRepository.delete(profile)

            // Sign out
            try await authService.signOut()
        } catch {
            handle(error: error)
        }
    }

    // MARK: - Private Methods

    private func fetchProfileFromBackend() async {
        do {
            guard let userId = await authService.currentUser?.id else {
                throw ProfileError.notAuthenticated
            }

            // TODO: Replace with actual API call when endpoint is ready
            // let response = try await apiClient.getUserProfile(userId: userId)

            // For now, create a default profile
            let currentUser = await authService.currentUser
            let profile = UserProfileModel(
                userID: userId,
                email: currentUser?.email ?? "",
                displayName: currentUser?
                    .email ?? "" // Using email as displayName since AuthUser doesn't have displayName
            )

            try await userProfileRepository.create(profile)
            profileState = .loaded(profile)
        } catch {
            profileState = .error(error)
            handle(error: error)
        }
    }

    private func syncProfile() async {
        do {
            try await userProfileRepository.sync()
        } catch {
            // Don't update UI state for background sync errors
            print("Profile sync error: \(error)")
        }
    }

    private func syncProfileUpdate(_ profile: UserProfileModel) async throws {
        // TODO: Implement actual API call
        // let updateRequest = UpdateUserProfileRequest(...)
        // try await apiClient.updateUserProfile(userId: profile.userId, request: updateRequest)

        // Mark as synced
        profile.syncStatus = .synced
        try await userProfileRepository.update(profile)
    }
}

// MARK: - Supporting Types

enum ProfileError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case updateFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "You must be signed in to access your profile"
        case .profileNotFound:
            "Profile not found"
        case .updateFailed:
            "Failed to update profile"
        }
    }
}

enum ActivityLevel: String, CaseIterable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extremelyActive = "Extremely Active"

    var description: String {
        switch self {
        case .sedentary:
            "Little or no exercise"
        case .lightlyActive:
            "Exercise 1-3 days/week"
        case .moderatelyActive:
            "Exercise 3-5 days/week"
        case .veryActive:
            "Exercise 6-7 days/week"
        case .extremelyActive:
            "Very hard exercise daily"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extremelyActive: 1.9
        }
    }
}
