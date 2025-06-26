//
//  AuthTokenDTO.swift
//  clarity-loop-frontend-v2
//
//  Data Transfer Object for authentication tokens
//

import Foundation
import ClarityDomain

/// DTO for authentication token response
struct AuthTokenDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}


// MARK: - Domain Mapping

extension AuthTokenDTO {
    /// Convert DTO to Domain Model
    func toDomainModel() -> AuthToken {
        AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )
    }
}

