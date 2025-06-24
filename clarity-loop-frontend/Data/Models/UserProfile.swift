import Foundation
import SwiftData

/// The SwiftData model for storing the user's profile information locally.
/// This entity allows for offline access to user data and reduces network requests.
/// It corresponds to the `UserSessionResponseDTO`.
@Model
final class UserProfile {
    /// The unique identifier for the user, matching the backend UUID.
    @Attribute(.unique) var id: UUID

    /// The user's email address.
    var email: String

    /// The user's first name.
    var firstName: String

    /// The user's last name.
    var lastName: String

    /// The user's assigned role (e.g., "user", "admin").
    var role: String

    /// A list of permissions assigned to the user.
    var permissions: [String]

    /// The current status of the user's account (e.g., "active", "pending_verification").
    var status: String

    /// A flag indicating if the user has verified their email address.
    var emailVerified: Bool

    /// A flag indicating if Multi-Factor Authentication is enabled for the user.
    var mfaEnabled: Bool

    /// The timestamp when the user account was created.
    var createdAt: Date

    /// The timestamp of the user's last login.
    var lastLogin: Date?

    /// A local-only timestamp indicating when this record was last synced from the backend.
    var lastSyncedAt: Date

    init(
        id: UUID,
        email: String,
        firstName: String,
        lastName: String,
        role: String,
        permissions: [String],
        status: String,
        emailVerified: Bool,
        mfaEnabled: Bool,
        createdAt: Date,
        lastLogin: Date?,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.permissions = permissions
        self.status = status
        self.emailVerified = emailVerified
        self.mfaEnabled = mfaEnabled
        self.createdAt = createdAt
        self.lastLogin = lastLogin
        self.lastSyncedAt = lastSyncedAt
    }

    /// A convenience initializer to create a `UserProfile` from a `UserSessionResponseDTO`.
    convenience init(from dto: UserSessionResponseDTO) {
        // Parse display name to extract first and last names
        let nameParts = dto.displayName.split(separator: " ", maxSplits: 1)
        let firstName = nameParts.first.map(String.init) ?? ""
        let lastName = nameParts.count > 1 ? String(nameParts[1]) : ""

        self.init(
            id: dto.userId ?? UUID(), // Use computed property that converts from string
            email: dto.email,
            firstName: firstName,
            lastName: lastName,
            role: dto.role,
            permissions: dto.permissions,
            status: dto.status,
            emailVerified: dto.emailVerified,
            mfaEnabled: dto.mfaEnabled,
            createdAt: dto.createdAt,
            lastLogin: dto.lastLogin
        )
    }
}
