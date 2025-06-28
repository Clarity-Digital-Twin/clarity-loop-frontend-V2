//
//  UserDTO.swift
//  clarity-loop-frontend-v2
//
//  Data Transfer Object for User entity
//

import Foundation
import ClarityDomain

/// DTO for User data transfer between API and domain
struct UserDTO: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let createdAt: String
    let lastLoginAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }
}

// MARK: - Domain Mapping

extension UserDTO {
    /// Convert DTO to Domain Entity
    func toDomainModel() throws -> User {
        guard let uuid = UUID(uuidString: id) else {
            throw DTOError.invalidUUID(id)
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        guard let createdDate = dateFormatter.date(from: createdAt) else {
            throw DTOError.invalidDate(createdAt)
        }
        
        let lastLoginDate = lastLoginAt.flatMap { dateFormatter.date(from: $0) }
        
        return User(
            id: uuid,
            email: email,
            firstName: firstName,
            lastName: lastName,
            createdAt: createdDate,
            updatedAt: createdDate,
            lastLoginAt: lastLoginDate
        )
    }
}

extension User {
    /// Convert Domain Entity to DTO
    func toDTO() -> UserDTO {
        let dateFormatter = ISO8601DateFormatter()
        
        return UserDTO(
            id: id.uuidString,
            email: email,
            firstName: firstName,
            lastName: lastName,
            createdAt: dateFormatter.string(from: createdAt),
            lastLoginAt: lastLoginAt.map { dateFormatter.string(from: $0) }
        )
    }
}
