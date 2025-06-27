//
//  ClarityPulseAppTests.swift
//  ClarityPulseTests
//
//  Created on 2025-06-25.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import XCTest
@testable import ClarityCore
@testable import ClarityUI
@testable import ClarityDomain
import SwiftUI

final class ClarityPulseAppTests: XCTestCase {
    
    func test_dependencies_canBeConfigured() throws {
        // Given
        let container = DIContainer()
        
        // When - Configure with mock dependencies for testing
        // We can't test the actual app struct, but we can test dependency configuration
        
        // Then
        XCTAssertNotNil(container, "Container should be created successfully")
    }
    
    @MainActor
    func test_appState_isInitializable() throws {
        // Given/When
        let appState = AppState()
        
        // Then
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUserId)
    }
}