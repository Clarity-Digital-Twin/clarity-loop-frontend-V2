import Foundation

// MARK: - Health Metric Types (matching backend HealthMetricType enum)

enum BackendHealthMetricType: String, Codable {
    case heartRate = "heart_rate"
    case heartRateVariability = "heart_rate_variability"
    case bloodPressure = "blood_pressure"
    case bloodOxygen = "blood_oxygen"
    case respiratoryRate = "respiratory_rate"
    case sleepAnalysis = "sleep_analysis"
    case activityLevel = "activity_level"
    case stressIndicators = "stress_indicators"
    case moodAssessment = "mood_assessment"
    case cognitiveMetrics = "cognitive_metrics"
    case environmental
    case bodyTemperature = "body_temperature"
    case bloodGlucose = "blood_glucose"
}

// MARK: - Backend-Compatible Health Metric

struct BackendHealthMetric: Codable {
    let metricId: UUID
    let metricType: BackendHealthMetricType
    let biometricData: BiometricDataDTO?
    let sleepData: SleepDataDTO?
    let activityData: ActivityDataDTO?
    let mentalHealthData: MentalHealthIndicatorDTO?
    let deviceId: String?
    let rawData: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
    let createdAt: Date

    init(
        metricId: UUID = UUID(),
        metricType: BackendHealthMetricType,
        biometricData: BiometricDataDTO? = nil,
        sleepData: SleepDataDTO? = nil,
        activityData: ActivityDataDTO? = nil,
        mentalHealthData: MentalHealthIndicatorDTO? = nil,
        deviceId: String? = nil,
        rawData: [String: AnyCodable]? = nil,
        metadata: [String: AnyCodable]? = nil,
        createdAt: Date = Date()
    ) {
        self.metricId = metricId
        self.metricType = metricType
        self.biometricData = biometricData
        self.sleepData = sleepData
        self.activityData = activityData
        self.mentalHealthData = mentalHealthData
        self.deviceId = deviceId
        self.rawData = rawData
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - Backend-Compatible Health Data Upload

struct BackendHealthDataUpload: Codable {
    let userId: UUID
    let metrics: [BackendHealthMetric]
    let uploadSource: String
    let clientTimestamp: Date
    let syncToken: String?

    init(
        userId: UUID,
        metrics: [BackendHealthMetric],
        uploadSource: String = "apple_health",
        clientTimestamp: Date = Date(),
        syncToken: String? = nil
    ) {
        self.userId = userId
        self.metrics = metrics
        self.uploadSource = uploadSource
        self.clientTimestamp = clientTimestamp
        self.syncToken = syncToken
    }
}

// MARK: - Conversion Extensions

extension HealthKitSampleDTO {
    /// Convert HealthKit sample to backend-compatible health metric
    func toBackendHealthMetric() -> BackendHealthMetric? {
        let metricType: BackendHealthMetricType
        var biometricData: BiometricDataDTO?
        var sleepData: SleepDataDTO?
        var activityData: ActivityDataDTO?
        
        switch sampleType {
        case "stepCount":
            metricType = .activityLevel
            activityData = ActivityDataDTO(
                steps: Int(value ?? 0),
                distance: nil,
                activeEnergy: nil,
                exerciseMinutes: nil,
                flightsClimbed: nil,
                vo2Max: nil,
                activeMinutes: nil,
                restingHeartRate: nil
            )

        case "restingHeartRate":
            metricType = .heartRate
            biometricData = BiometricDataDTO(
                heartRate: value,
                bloodPressureSystolic: nil,
                bloodPressureDiastolic: nil,
                oxygenSaturation: nil,
                heartRateVariability: nil,
                respiratoryRate: nil,
                bodyTemperature: nil,
                bloodGlucose: nil
            )

        case "heartRate":
            metricType = .heartRate
            biometricData = BiometricDataDTO(
                heartRate: value,
                bloodPressureSystolic: nil,
                bloodPressureDiastolic: nil,
                oxygenSaturation: nil,
                heartRateVariability: nil,
                respiratoryRate: nil,
                bodyTemperature: nil,
                bloodGlucose: nil
            )

        case "sleepAnalysis":
            metricType = .sleepAnalysis
            let totalMinutes = Int(value ?? 0)
            let efficiency = metadata?["sleep_efficiency"]?.value as? Double ?? 0.85

            sleepData = SleepDataDTO(
                totalSleepMinutes: totalMinutes,
                sleepEfficiency: efficiency,
                timeToSleepMinutes: nil,
                wakeCount: nil,
                sleepStages: nil,
                sleepStart: startDate,
                sleepEnd: endDate
            )

        default:
            return nil
        }

        return BackendHealthMetric(
            metricType: metricType,
            biometricData: biometricData,
            sleepData: sleepData,
            activityData: activityData,
            deviceId: sourceRevision?.source.bundleIdentifier,
            metadata: metadata,
            createdAt: endDate
        )
    }
}

extension HealthKitUploadRequestDTO {
    /// Convert to backend-compatible upload request
    func toBackendUploadRequest() -> BackendHealthDataUpload? {
        // Convert userId string to UUID
        guard let userUUID = UUID(uuidString: userId) else {
            return nil
        }

        // Convert samples to metrics
        let metrics = samples.compactMap { $0.toBackendHealthMetric() }

        return BackendHealthDataUpload(
            userId: userUUID,
            metrics: metrics,
            uploadSource: "apple_health",
            clientTimestamp: timestamp,
            syncToken: nil
        )
    }
}
