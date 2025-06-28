//
//  LoginUseCaseProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for login use case
//

import Foundation

/// Protocol defining the login use case interface
public protocol LoginUseCaseProtocol: Sendable {
    /// Execute login with email and password
    @MainActor
    func execute(email: String, password: String) async throws -> User
}
