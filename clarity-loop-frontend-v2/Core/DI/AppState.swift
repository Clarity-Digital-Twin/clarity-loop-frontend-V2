//
//  AppState.swift
//  clarity-loop-frontend-v2
//
//  Global app state management
//

import Foundation
import ClarityDomain

/// Global app state for managing authentication and navigation
@MainActor
@Observable
public final class AppState {
    
    // MARK: - Properties
    
    public private(set) var isAuthenticated: Bool = false
    public private(set) var currentUser: User?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Log in with a user
    public func login(with user: User) {
        currentUser = user
        isAuthenticated = true
    }
    
    /// Log out the current user
    public func logout() {
        currentUser = nil
        isAuthenticated = false
    }
}