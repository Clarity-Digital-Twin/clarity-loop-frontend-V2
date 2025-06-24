import Foundation
import SwiftData

/// The SwiftData model for caching raw PAT (Pretrained Actigraphy Transformer) analysis results.
/// Storing this locally can prevent re-running expensive analyses on the backend.
@Model
final class PATAnalysisEntity {
    /// The unique identifier for the analysis job.
    @Attribute(.unique) var id: String

    /// The processing status of the analysis (e.g., "completed", "failed").
    var status: String

    /// The timestamp when the analysis was completed.
    var completedAt: Date?

    /// A JSON-encoded dictionary of the extracted PAT features.
    var patFeatures: Data?

    /// A JSON-encoded array representing the activity embedding vector.
    var activityEmbedding: Data?

    /// A local-only timestamp indicating when this record was last synced.
    var lastSyncedAt: Date

    init(
        id: String,
        status: String,
        completedAt: Date?,
        patFeatures: Data?,
        activityEmbedding: Data?,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.completedAt = completedAt
        self.patFeatures = patFeatures
        self.activityEmbedding = activityEmbedding
        self.lastSyncedAt = lastSyncedAt
    }
}
