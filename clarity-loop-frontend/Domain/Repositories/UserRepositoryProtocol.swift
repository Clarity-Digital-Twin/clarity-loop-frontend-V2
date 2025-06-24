import Foundation

/// A protocol defining the contract for a repository that manages user profile data.
protocol UserRepositoryProtocol {
    /// Gets the current user's profile from the backend.
    func getCurrentUserProfile() async throws -> UserProfile

    /// Updates the current user's profile.
    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile

    /// Deletes the current user's account.
    func deleteUserAccount() async throws

    /// Gets the user's privacy preferences.
    func getPrivacyPreferences() async throws -> UserPrivacyPreferencesDTO

    /// Updates the user's privacy preferences.
    func updatePrivacyPreferences(_ preferences: UserPrivacyPreferencesDTO) async throws
}
