import Foundation
import SwiftData

final class SwiftDataConfigurator {
    // MARK: - Properties

    static let shared = SwiftDataConfigurator()

    private init() {}

    // MARK: - Configuration

    func createModelContainer(isPreview: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            HealthMetric.self,
            UserProfileModel.self,
            PATAnalysis.self,
            AIInsight.self,
            PersistedOfflineOperation.self,
        ])

        let modelConfiguration = if isPreview {
            // In-memory configuration for previews
            ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            // 🔥 CRITICAL FIX: Disable CloudKit to prevent crashes
            // Production configuration WITHOUT CloudKit (for now)
            ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
                // cloudKitDatabase: .automatic  // DISABLED - causing crashes
            )
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            return container
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            throw error
        }
    }

    // MARK: - Test Support

    func createTestContainer() throws -> ModelContainer {
        // For tests, use a minimal model that doesn't depend on other models
        let schema = Schema([
            TestOnlyModel.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}

// MARK: - SwiftData Error

enum SwiftDataError: LocalizedError {
    case containerCreationFailed(Error)
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case let .containerCreationFailed(error):
            return "Failed to create SwiftData container: \(error.localizedDescription)"
        case let .migrationFailed(error):
            return "Failed to migrate SwiftData schema: \(error.localizedDescription)"
        }
    }
}
