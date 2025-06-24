import Foundation
import SwiftData

/// A SwiftData model representing a single, flattened health metric record for local persistence.
/// This structure is optimized for efficient querying and display in the UI.
@Model
final class HealthMetricEntity {
    /// The unique identifier for the metric, matching the backend `metricId`.
    @Attribute(.unique) var id: UUID

    /// The type of metric (e.g., "heart_rate", "sleep_analysis").
    var type: String

    /// The primary timestamp for the metric, used for sorting and querying by date.
    var date: Date

    // MARK: - Biometric Fields

    var heartRate: Double?
    var systolicBP: Int?
    var diastolicBP: Int?
    var oxygenSaturation: Double?
    var hrv: Double?
    var respiratoryRate: Double?
    var bodyTemperature: Double?
    var bloodGlucose: Double?

    // MARK: - Sleep Fields

    var totalSleepMinutes: Int?
    var sleepEfficiency: Double?
    var sleepStart: Date?
    var sleepEnd: Date?

    // MARK: - Activity Fields

    var steps: Int?
    var distance: Double?
    var activeEnergy: Double?
    var exerciseMinutes: Int?
    var flightsClimbed: Int?
    var vo2Max: Double?
    var activeMinutes: Int?
    var restingHeartRate: Double?

    // MARK: - Mental Health Fields

    var moodScore: String?
    var stressLevel: Double?
    var anxietyLevel: Double?
    var energyLevel: Double?
    var focusRating: Double?
    var socialInteractionMinutes: Int?
    var meditationMinutes: Int?

    // MARK: - Metadata

    /// The identifier for the source device.
    var deviceId: String?

    /// The original, full DTO stored as a JSON blob for completeness and future-proofing.
    var rawJson: Data?

    /// A local-only timestamp indicating when this record was last synced.
    var lastSyncedAt: Date

    init(
        id: UUID,
        type: String,
        date: Date,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.date = date
        self.lastSyncedAt = lastSyncedAt
    }
}
