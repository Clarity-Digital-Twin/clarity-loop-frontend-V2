import Foundation

// MARK: - UserSessionResponseDTO to AuthUser Conversion

extension UserSessionResponseDTO {
    /// Converts this DTO to an AuthUser domain model
    var authUser: AuthUser {
        AuthUser(
            id: id,
            email: email,
            fullName: displayName,
            isEmailVerified: isEmailVerified
        )
    }
}
