import SwiftData
import Foundation

/// Service for persisting user data locally using SwiftData
@MainActor
final class UserDataService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Save or update user profile data
    func saveUser(_ user: AuthUser) async throws {
        // Check if user already exists
        let userIdToCheck = user.id
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { model in
                model.userID == userIdToCheck
            }
        )
        
        let existingUsers = try modelContext.fetch(descriptor)
        
        if let existingUser = existingUsers.first {
            // Update existing user
            existingUser.email = user.email
            existingUser.displayName = user.fullName ?? user.email
            existingUser.lastSync = Date()
        } else {
            // Create new user
            let userModel = UserProfileModel(
                userID: user.id,
                email: user.email,
                displayName: user.fullName ?? user.email
            )
            userModel.lastSync = Date()
            modelContext.insert(userModel)
        }
        
        try modelContext.save()
    }
    
    /// Get cached user profile
    func getUser(id: String) async throws -> UserProfileModel? {
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { model in
                model.userID == id
            }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Delete all user data (for logout)
    func deleteAllUserData() async throws {
        // Delete user profile
        let userDescriptor = FetchDescriptor<UserProfileModel>()
        let users = try modelContext.fetch(userDescriptor)
        for user in users {
            modelContext.delete(user)
        }
        
        // Delete health metrics
        let metricsDescriptor = FetchDescriptor<HealthMetric>()
        let metrics = try modelContext.fetch(metricsDescriptor)
        for metric in metrics {
            modelContext.delete(metric)
        }
        
        // Delete PAT analyses
        let patDescriptor = FetchDescriptor<PATAnalysis>()
        let analyses = try modelContext.fetch(patDescriptor)
        for analysis in analyses {
            modelContext.delete(analysis)
        }
        
        // Delete insights
        let insightDescriptor = FetchDescriptor<AIInsight>()
        let insights = try modelContext.fetch(insightDescriptor)
        for insight in insights {
            modelContext.delete(insight)
        }
        
        try modelContext.save()
    }
}