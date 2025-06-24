import Foundation
import SwiftData
@testable import clarity_loop_frontend

// MARK: - Mock User Profile Repository

@MainActor
final class MockUserProfileRepository: ObservableBaseRepository<UserProfileModel>, UserProfileRepositoryProtocol {
    
    // MARK: - Mock Properties
    
    var shouldFail = false
    var mockError: Error = NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    var mockProfile: UserProfileModel?
    
    // Behavior tracking
    var fetchCurrentUserCalled = false
    var updatePreferencesCalled = false
    var syncCalled = false
    var createCalled = false
    var updateCalled = false
    var deleteCalled = false
    
    var capturedPreferences: UserPreferences?
    var capturedProfile: UserProfileModel?
    
    // MARK: - UserProfileRepositoryProtocol Methods
    
    func fetchCurrentUser() async throws -> UserProfileModel? {
        fetchCurrentUserCalled = true
        
        if shouldFail {
            throw mockError
        }
        
        return mockProfile
    }
    
    func updatePreferences(_ preferences: UserPreferences) async throws {
        updatePreferencesCalled = true
        capturedPreferences = preferences
        
        if shouldFail {
            throw mockError
        }
        
        guard let profile = mockProfile else {
            throw RepositoryError.entityNotFound
        }
        
        profile.preferences = preferences
    }
    
    // MARK: - Override Base Methods
    
    func create(_ model: UserProfileModel) async throws {
        createCalled = true
        capturedProfile = model
        
        if shouldFail {
            throw mockError
        }
        
        mockProfile = model
    }
    
    func update(_ model: UserProfileModel) async throws {
        updateCalled = true
        capturedProfile = model
        
        if shouldFail {
            throw mockError
        }
        
        mockProfile = model
    }
    
    func delete(_ model: UserProfileModel) async throws {
        deleteCalled = true
        capturedProfile = model
        
        if shouldFail {
            throw mockError
        }
        
        mockProfile = nil
    }
    
    override func sync() async throws {
        syncCalled = true
        
        if shouldFail {
            throw mockError
        }
        
        // Mark profile as synced
        if let profile = mockProfile {
            profile.syncStatus = .synced
            profile.lastSync = Date()
        }
    }
    
    override func syncBatch(_ models: [UserProfileModel]) async throws {
        if shouldFail {
            throw mockError
        }
        
        for model in models {
            model.syncStatus = .synced
            model.lastSync = Date()
        }
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        shouldFail = false
        mockProfile = nil
        fetchCurrentUserCalled = false
        updatePreferencesCalled = false
        syncCalled = false
        createCalled = false
        updateCalled = false
        deleteCalled = false
        capturedPreferences = nil
        capturedProfile = nil
    }
    
    func setupMockProfile(
        userId: String = "test-user-123",
        email: String = "test@example.com",
        displayName: String = "Test User"
    ) -> UserProfileModel {
        let profile = UserProfileModel(
            userID: userId,
            email: email,
            displayName: displayName
        )
        mockProfile = profile
        return profile
    }
}