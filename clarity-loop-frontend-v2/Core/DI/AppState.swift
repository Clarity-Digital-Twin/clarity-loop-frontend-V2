//
//  AppState.swift
//  clarity-loop-frontend-v2
//
//  Global app state management
//

import Foundation

/// Global app state for managing authentication and navigation
@MainActor
@Observable
public final class AppState {
    
    // MARK: - Properties
    
    public private(set) var isAuthenticated: Bool = false
    public private(set) var currentUserId: UUID?
    public private(set) var currentUserEmail: String?
    public private(set) var currentUserName: String?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Log in with user information
    public func login(userId: UUID, email: String, name: String) {
        currentUserId = userId
        currentUserEmail = email
        currentUserName = name
        isAuthenticated = true
    }
    
    /// Log out the current user
    public func logout() {
        currentUserId = nil
        currentUserEmail = nil
        currentUserName = nil
        isAuthenticated = false
    }
}
