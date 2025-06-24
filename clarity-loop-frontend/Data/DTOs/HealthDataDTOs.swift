import Foundation

// Note: The `AnyCodable` type from the `AnyCodable.swift` file is used here
// to handle dynamic JSON values in metadata fields.

// MARK: - Processing Status (matching backend)

enum ProcessingStatus: String, Codable {
    case received = "received"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case requiresReview = "requires_review"
}

// MARK: - Mood Scale (matching backend)

enum MoodScale: String, Codable {
    case veryLow = "very_low"
    case low = "low"
    case neutral = "neutral"
    case good = "good"
    case excellent = "excellent"
}

// MARK: - Main Health Metric DTO

struct HealthMetricDTO: Codable, Identifiable {
    var id: UUID { metricId }

    let metricId: UUID
    let metricType: String // Consider creating a specific enum for this
    let biometricData: BiometricDataDTO?
    let sleepData: SleepDataDTO?
    let activityData: ActivityDataDTO?
    let mentalHealthData: MentalHealthIndicatorDTO?
    let deviceId: String?
    let rawData: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
    let createdAt: Date
}

// MARK: - Component DTOs

struct BiometricDataDTO: Codable {
    let heartRate: Double?
    let bloodPressureSystolic: Int?
    let bloodPressureDiastolic: Int?
    let oxygenSaturation: Double?
    let heartRateVariability: Double?
    let respiratoryRate: Double?
    let bodyTemperature: Double?
    let bloodGlucose: Double?
}

struct SleepDataDTO: Codable {
    let totalSleepMinutes: Int
    let sleepEfficiency: Double
    let timeToSleepMinutes: Int?
    let wakeCount: Int?
    let sleepStages: [String: Int]?
    let sleepStart: Date
    let sleepEnd: Date
}

struct ActivityDataDTO: Codable {
    let steps: Int?
    let distance: Double?
    let activeEnergy: Double?
    let exerciseMinutes: Int?
    let flightsClimbed: Int?
    let vo2Max: Double?
    let activeMinutes: Int?
    let restingHeartRate: Double?
}

struct MentalHealthIndicatorDTO: Codable {
    let moodScore: String?
    let stressLevel: Double?
    let anxietyLevel: Double?
    let energyLevel: Double?
    let focusRating: Double?
    let socialInteractionMinutes: Int?
    let meditationMinutes: Int?
    let notes: String?
    let timestamp: Date
}

// MARK: - Pagination DTO

struct PaginatedMetricsResponseDTO: Codable {
    let data: [HealthMetricDTO]
    // Pagination will be added when backend finalizes the structure
}

// MARK: - Health Data Upload DTOs

struct HealthDataUploadDTO: Codable {
    let userId: UUID
    let metrics: [HealthMetricDTO]
    let uploadSource: String
    let clientTimestamp: Date
    let syncToken: String?
}

struct HealthDataResponseDTO: Codable {
    let processingId: UUID
    let status: String
    let acceptedMetrics: Int
    let rejectedMetrics: Int
    let validationErrors: [String] // Simplified for now
    let estimatedProcessingTime: Int?
    let syncToken: String?
    let message: String
    let timestamp: Date
}

/// DTO for health data processing status queries.
struct HealthDataProcessingStatusDTO: Codable {
    let processingId: UUID
    let status: String // "pending", "processing", "completed", "failed"
    let progress: Double // 0.0 to 1.0
    let processedMetrics: Int
    let totalMetrics: Int?
    let estimatedTimeRemaining: Int? // in seconds
    let completedAt: Date?
    let errors: [String]? // Simplified for now
    let message: String?
}
