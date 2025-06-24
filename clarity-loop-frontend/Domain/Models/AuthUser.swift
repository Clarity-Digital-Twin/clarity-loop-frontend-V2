import Foundation

/// Domain model representing an authenticated user
/// This abstracts away authentication provider-specific types from the domain layer
struct AuthUser: Equatable {
    let id: String
    let email: String
    let fullName: String?
    let isEmailVerified: Bool

    // Legacy property for backward compatibility
    var uid: String { id }

    init(id: String, email: String, fullName: String? = nil, isEmailVerified: Bool = false) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.isEmailVerified = isEmailVerified
    }

    // Legacy initializer for backward compatibility
    init(uid: String, email: String?, isEmailVerified: Bool = false) {
        self.id = uid
        self.email = email ?? ""
        self.fullName = nil
        self.isEmailVerified = isEmailVerified
    }
}
