import Foundation

/// A concrete implementation of the `UserRepositoryProtocol` that manages user data
/// with the remote backend API.
class RemoteUserRepository: UserRepositoryProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getCurrentUserProfile() async throws -> UserProfile {
        // TODO: Add API endpoint for getting user profile
        print("⚠️ RemoteUserRepository: getCurrentUserProfile not implemented, returning dummy profile")
        // Return dummy profile to prevent crash during development
        return UserProfile(
            id: UUID(),
            email: "dummy@example.com",
            firstName: "Dummy",
            lastName: "User",
            role: "user",
            permissions: [],
            status: "active",
            emailVerified: false,
            mfaEnabled: false,
            createdAt: Date(),
            lastLogin: nil
        )
    }

    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        // TODO: Add API endpoint for updating user profile
        print("⚠️ RemoteUserRepository: updateUserProfile not implemented, returning unchanged profile")
        // Return unchanged profile to prevent crash during development
        return profile
    }

    func deleteUserAccount() async throws {
        // TODO: Add API endpoint for deleting user account
        print("⚠️ RemoteUserRepository: deleteUserAccount not implemented, no-op")
        // No-op to prevent crash during development
    }

    func getPrivacyPreferences() async throws -> UserPrivacyPreferencesDTO {
        // TODO: Add API endpoint for getting privacy preferences
        print("⚠️ RemoteUserRepository: getPrivacyPreferences not implemented, returning default preferences")
        // Return default preferences to prevent crash during development
        return UserPrivacyPreferencesDTO(
            shareDataForResearch: false,
            enableAnalytics: false,
            marketingEmails: false,
            pushNotifications: true,
            dataRetentionPeriod: 365,
            allowThirdPartyIntegrations: false
        )
    }

    func updatePrivacyPreferences(_ preferences: UserPrivacyPreferencesDTO) async throws {
        // TODO: Add API endpoint for updating privacy preferences
        print("⚠️ RemoteUserRepository: updatePrivacyPreferences not implemented, no-op")
        // No-op to prevent crash during development
    }
}
