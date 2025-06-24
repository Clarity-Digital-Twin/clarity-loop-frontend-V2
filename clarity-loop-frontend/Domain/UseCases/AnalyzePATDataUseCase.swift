import Foundation
import UIKit

final class AnalyzePATDataUseCase {
    private let apiClient: APIClientProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        apiClient: APIClientProtocol,
        healthKitService: HealthKitServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.apiClient = apiClient
        self.healthKitService = healthKitService
        self.authService = authService
    }

    func executeStepAnalysis(
        startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        endDate: Date = Date()
    ) async throws -> PATAnalysisResult {
        // Fetch step data from HealthKit
        let stepData = try await collectStepData(from: startDate, to: endDate)

        // Create request DTO
        let userId = await authService.currentUser?.id ?? "unknown"
        let request = StepDataRequestDTO(
            userId: userId,
            stepData: stepData,
            analysisType: "comprehensive",
            timeRange: TimeRangeDTO(startDate: startDate, endDate: endDate)
        )

        // Submit for analysis
        let analysisResponse = try await apiClient.analyzeStepData(requestDTO: request)

        // Poll for completion if needed
        if analysisResponse.status == "processing" {
            return try await pollForCompletion(analysisId: analysisResponse.analysisId)
        } else {
            // Convert step analysis data to generic PAT features
            let patFeatures: [String: AnyCodable]? = analysisResponse.data.map { stepData in
                [
                    "averageStepsPerDay": AnyCodable(stepData.dailyStepPattern.averageStepsPerDay),
                    "consistencyScore": AnyCodable(stepData.dailyStepPattern.consistencyScore),
                    "activityLevel": AnyCodable(stepData.activityInsights.activityLevel),
                    "goalProgress": AnyCodable(stepData.activityInsights.goalProgress),
                    "estimatedCaloriesBurned": AnyCodable(stepData.healthMetrics.estimatedCaloriesBurned),
                ]
            }

            return PATAnalysisResult(
                analysisId: analysisResponse.analysisId,
                status: analysisResponse.status,
                patFeatures: patFeatures,
                confidence: nil, // Not available in step analysis
                completedAt: analysisResponse.createdAt, // Using creation date as completion
                error: analysisResponse.message // Using message as error if needed
            )
        }
    }

    func executeActigraphyAnalysis(actigraphyData: [ActigraphyDataPointDTO]) async throws -> PATAnalysisResult {
        let userId = await authService.currentUser?.id ?? "unknown"
        let startDate = actigraphyData.first?.timestamp ?? Date()
        let endDate = actigraphyData.last?.timestamp ?? Date()
        let request = DirectActigraphyRequestDTO(
            userId: userId,
            actigraphyData: actigraphyData,
            analysisType: "comprehensive",
            timeRange: TimeRangeDTO(startDate: startDate, endDate: endDate)
        )

        let analysisResponse = try await apiClient.analyzeActigraphy(requestDTO: request)

        if analysisResponse.status == "processing" {
            return try await pollForCompletion(analysisId: analysisResponse.analysisId)
        } else {
            // Convert actigraphy analysis data to generic PAT features
            let patFeatures: [String: AnyCodable]? = analysisResponse.data.map { actigraphyData in
                [
                    "totalSleepTime": AnyCodable(actigraphyData.sleepMetrics.totalSleepTime),
                    "sleepEfficiency": AnyCodable(actigraphyData.sleepMetrics.sleepEfficiency),
                    "sleepLatency": AnyCodable(actigraphyData.sleepMetrics.sleepLatency),
                    "dailyActivityScore": AnyCodable(actigraphyData.activityPatterns.dailyActivityScore),
                    "circadianPhase": AnyCodable(actigraphyData.circadianRhythm.phase),
                    "circadianAmplitude": AnyCodable(actigraphyData.circadianRhythm.amplitude),
                ]
            }

            return PATAnalysisResult(
                analysisId: analysisResponse.analysisId,
                status: analysisResponse.status,
                patFeatures: patFeatures,
                confidence: nil, // Not available in actigraphy analysis
                completedAt: analysisResponse.createdAt, // Using creation date as completion
                error: analysisResponse.message // Using message as error if needed
            )
        }
    }

    func getAnalysisResult(analysisId: String) async throws -> PATAnalysisResponseDTO {
        try await apiClient.getPATAnalysis(id: analysisId)
    }

    // MARK: - Private Methods

    private func collectStepData(from startDate: Date, to endDate: Date) async throws -> [StepDataPointDTO] {
        var stepData: [StepDataPointDTO] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            do {
                let steps = try await healthKitService.fetchDailySteps(for: currentDate)
                let timestamp = calendar.startOfDay(for: currentDate)

                stepData.append(StepDataPointDTO(
                    timestamp: timestamp,
                    stepCount: Int(steps),
                    source: "HealthKit"
                ))

                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            } catch {
                // Skip days with no data
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }

        return stepData
    }

    private func categorizeActivityLevel(steps: Double) -> String {
        switch steps {
        case 0..<1000:
            "sedentary"
        case 1000..<5000:
            "low"
        case 5000..<10000:
            "moderate"
        case 10000..<15000:
            "high"
        default:
            "very_high"
        }
    }

    private func pollForCompletion(
        analysisId: String,
        maxAttempts: Int = 30,
        delaySeconds: UInt64 = 10
    ) async throws -> PATAnalysisResult {
        for attempt in 1...maxAttempts {
            let response = try await apiClient.getPATAnalysis(id: analysisId)

            if response.status == "completed" || response.status == "failed" {
                // Convert [String: Double] to [String: AnyCodable]
                let patFeatures: [String: AnyCodable]? = response.patFeatures?.mapValues { AnyCodable($0) }

                return PATAnalysisResult(
                    analysisId: response.id,
                    status: response.status,
                    patFeatures: patFeatures,
                    confidence: response.analysis?.confidenceScore,
                    completedAt: response.completedAt,
                    error: response.errorMessage
                )
            }

            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }

        throw PATAnalysisError.analysisTimeout
    }
}

struct PATAnalysisResult: Equatable {
    let analysisId: String
    let status: String
    let patFeatures: [String: AnyCodable]?
    let confidence: Double?
    let completedAt: Date?
    let error: String?

    var isCompleted: Bool {
        status == "completed"
    }

    var isFailed: Bool {
        status == "failed"
    }

    var isProcessing: Bool {
        status == "processing"
    }
}
