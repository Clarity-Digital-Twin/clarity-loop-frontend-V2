import Foundation

// MARK: - HealthKit Upload DTOs

/// A DTO for uploading individual HealthKit samples to the backend.
struct HealthKitSampleDTO: Codable {
    let sampleType: String // e.g., "stepCount", "heartRate", "sleepAnalysis"
    let value: Double? // For quantity types
    let categoryValue: Int? // For category types like sleep
    let unit: String? // e.g., "count", "count/min"
    let startDate: Date
    let endDate: Date
    let metadata: [String: AnyCodable]?
    let sourceRevision: SourceRevisionDTO?
}

/// A DTO representing the source revision information for a HealthKit sample.
struct SourceRevisionDTO: Codable {
    let source: SourceDTO
    let version: String?
    let productType: String?
    let operatingSystemVersion: String?
}

/// A DTO representing the source of a HealthKit sample.
struct SourceDTO: Codable {
    let name: String
    let bundleIdentifier: String
}

/// A DTO for batch uploading multiple HealthKit samples.
struct HealthKitUploadRequestDTO: Codable {
    let userId: String
    let samples: [HealthKitSampleDTO]
    let deviceInfo: DeviceInfoDTO?
    let timestamp: Date
}

/// A DTO for device information during HealthKit uploads.
struct DeviceInfoDTO: Codable {
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let appVersion: String
    let timeZone: String
}

/// A DTO for the response after uploading HealthKit data.
struct HealthKitUploadResponseDTO: Codable {
    let success: Bool
    let uploadId: String
    let processedSamples: Int
    let skippedSamples: Int
    let errors: [String]?
    let message: String?
}

/// A DTO for requesting a sync of HealthKit data for a specific date range.
struct HealthKitSyncRequestDTO: Codable {
    let userId: String
    let startDate: Date
    let endDate: Date
    let dataTypes: [String] // e.g., ["stepCount", "heartRate", "sleepAnalysis"]
    let forceRefresh: Bool
}

/// A DTO for the response of a HealthKit sync request.
struct HealthKitSyncResponseDTO: Codable {
    let success: Bool
    let syncId: String
    let status: String // "initiated", "in_progress", "completed", "failed"
    let estimatedDuration: TimeInterval?
    let message: String?
}

/// A DTO for querying the status of a HealthKit sync operation.
struct HealthKitSyncStatusDTO: Codable {
    let syncId: String
    let status: String
    let progress: Double // 0.0 to 1.0
    let processedSamples: Int
    let totalSamples: Int?
    let errors: [String]?
    let completedAt: Date?
}

/// A DTO for upload status queries.
struct HealthKitUploadStatusDTO: Codable {
    let uploadId: String
    let status: String
    let progress: Double
    let processedSamples: Int
    let totalSamples: Int?
    let errors: [String]?
    let completedAt: Date?
    let message: String?
}
