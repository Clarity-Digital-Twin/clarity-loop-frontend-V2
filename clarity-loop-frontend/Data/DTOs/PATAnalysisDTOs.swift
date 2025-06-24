import Foundation

// MARK: - PAT Analysis DTOs

struct PATAnalysisResponseDTO: Codable {
    let id: String
    let status: String
    let patFeatures: [String: Double]?
    let analysis: PATAnalysisDataDTO?
    let errorMessage: String?
    let createdAt: Date
    let completedAt: Date?
}

struct PATAnalysisDataDTO: Codable {
    let sleepStages: [String]?
    let clinicalInsights: [String]?
    let confidenceScore: Double?
    let sleepEfficiency: Double?
    let totalSleepTime: Int?
    let wakeAfterSleepOnset: Int?
    let sleepLatency: Int?
}

// MARK: - PAT Request DTOs

struct StepDataRequestDTO: Codable {
    let userId: String
    let stepData: [StepDataPointDTO]
    let analysisType: String
    let timeRange: TimeRangeDTO
}

struct StepDataPointDTO: Codable {
    let timestamp: Date
    let stepCount: Int
    let source: String?
}

struct DirectActigraphyRequestDTO: Codable {
    let userId: String
    let actigraphyData: [ActigraphyDataPointDTO]
    let analysisType: String
    let timeRange: TimeRangeDTO
}

struct ActigraphyDataPointDTO: Codable {
    let timestamp: Date
    let activityLevel: Double
    let lightExposure: Double?
    let temperature: Double?
    let heartRate: Double?
}

struct TimeRangeDTO: Codable {
    let startDate: Date
    let endDate: Date
}

// MARK: - PAT Service DTOs

struct PATServiceHealthDTO: Codable {
    let service: String
    let status: String
    let model: PATModelInfoDTO
    let timestamp: Date
    let capabilities: [String]
    let version: String
}

struct PATModelInfoDTO: Codable {
    let modelName: String
    let projectId: String
    let initialized: Bool
    let capabilities: [String]
}

// MARK: - Generic Analysis Response

struct AnalysisResponseDTO<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let analysisId: String
    let status: String
    let message: String?
    let estimatedCompletionTime: Int?
    let createdAt: Date
}

// MARK: - Actigraphy Analysis DTO

struct ActigraphyAnalysisDTO: Codable {
    let sleepMetrics: SleepMetricsDTO
    let activityPatterns: ActivityPatternsDTO
    let circadianRhythm: CircadianRhythmDTO
    let recommendations: [String]
}

struct SleepMetricsDTO: Codable {
    let totalSleepTime: Int
    let sleepEfficiency: Double
    let sleepLatency: Int
    let wakeAfterSleepOnset: Int
    let numberOfAwakenings: Int
    let sleepStages: [String]
}

struct ActivityPatternsDTO: Codable {
    let dailyActivityScore: Double
    let peakActivityTime: String
    let restPeriods: [RestPeriodDTO]
    let activityVariability: Double
}

struct RestPeriodDTO: Codable {
    let startTime: Date
    let endTime: Date
    let restQuality: Double
}

struct CircadianRhythmDTO: Codable {
    let phase: Double
    let amplitude: Double
    let stability: Double
    let regularity: Double
    let recommendations: [String]
}

// MARK: - Step Analysis DTO

struct StepAnalysisDTO: Codable {
    let dailyStepPattern: DailyStepPatternDTO
    let activityInsights: ActivityInsightsDTO
    let healthMetrics: StepHealthMetricsDTO
    let recommendations: [String]
}

struct DailyStepPatternDTO: Codable {
    let averageStepsPerDay: Double
    let peakActivityHours: [Int]
    let consistencyScore: Double
    let trendsOverTime: [String]
}

struct ActivityInsightsDTO: Codable {
    let activityLevel: String
    let goalProgress: Double
    let improvementAreas: [String]
    let strengths: [String]
}

struct StepHealthMetricsDTO: Codable {
    let estimatedCaloriesBurned: Double
    let activeMinutesPerDay: Double
    let sedentaryTimePercentage: Double
}

// MARK: - Type Aliases for API Client

typealias StepAnalysisResponseDTO = AnalysisResponseDTO<StepAnalysisDTO>
typealias ActigraphyAnalysisResponseDTO = AnalysisResponseDTO<ActigraphyAnalysisDTO>
