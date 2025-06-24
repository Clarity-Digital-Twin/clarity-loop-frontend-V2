import Foundation
import Observation
import SwiftData

// MARK: - User Profile Repository Implementation

@Observable
final class UserProfileRepository: ObservableBaseRepository<UserProfileModel>, UserProfileRepositoryProtocol {
    // MARK: - Query Operations

    func fetchCurrentUser() async throws -> UserProfileModel? {
        // For now, fetch the first user profile
        // In a real app, this would use the authenticated user's ID
        let descriptor = FetchDescriptor<UserProfileModel>()
        let results = try await fetch(descriptor: descriptor)
        return results.first
    }

    func updatePreferences(_ preferences: UserPreferences) async throws {
        guard let currentUser = try await fetchCurrentUser() else {
            throw RepositoryError.entityNotFound
        }

        currentUser.preferences = preferences
        try await update(currentUser)
    }

    // MARK: - Sync Operations

    override func sync() async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }

        // TODO: Implement actual sync with backend
        // For now, just mark as synced
        if let user = try await fetchCurrentUser() {
            user.syncStatus = .synced
            user.lastSync = Date()
            try modelContext.save()
        }

        await updateSyncStatus(pendingCount: 0)
    }

    override func syncBatch(_ models: [UserProfileModel]) async throws {
        // User profiles are typically synced individually
        for _ in models {
            try await sync()
        }
    }

    override func resolveSyncConflicts(for models: [UserProfileModel]) async throws {
        // For user profiles, server typically wins to ensure consistency
        // In a real implementation, we would fetch the server version
        for model in models {
            model.syncStatus = .pending
        }
        try modelContext.save()
    }
}
