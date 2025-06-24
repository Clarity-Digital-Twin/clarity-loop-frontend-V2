import Foundation
import SwiftData

/// A singleton controller to manage the SwiftData stack for the application.
@MainActor
final class PersistenceController {
    /// The shared singleton instance of the persistence controller.
    static let shared = PersistenceController()

    /// The main SwiftData model container.
    let container: ModelContainer

    /// The private initializer to set up the schema and container.
    private init() {
        let schema = Schema([
            UserProfile.self,
            HealthMetricEntity.self,
            InsightEntity.self,
            PATAnalysisEntity.self,
        ])

        let config = ModelConfiguration("ClarityPulseDB", schema: schema, isStoredInMemoryOnly: false)

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            print("✅ PersistenceController: SwiftData container initialized successfully")
        } catch {
            // During background launch, SwiftData may fail to initialize
            // Create an in-memory fallback to prevent app crash
            print("⚠️ PersistenceController: SwiftData container failed, using in-memory fallback: \(error)")

            let fallbackConfig = ModelConfiguration(
                "ClarityPulseFallbackDB",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                self.container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                print("✅ PersistenceController: In-memory fallback container created")
            } catch {
                // If even in-memory fails, create minimal container without persistent storage
                print("🚨 PersistenceController: Even in-memory failed, creating minimal container")
                self.container = try! ModelContainer(for: schema, configurations: [])
            }
        }
    }
}
