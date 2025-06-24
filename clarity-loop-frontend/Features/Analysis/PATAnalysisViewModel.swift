import Foundation
import Observation
import SwiftData

// MARK: - PAT Analysis Errors

enum PATAnalysisError: LocalizedError {
    case fetchFailed(underlying: Error)
    case analysisTimeout
    case analysisFailed(message: String)
    case pollingFailed(underlying: Error)
    case noHealthData
    case insufficientData

    var errorDescription: String? {
        switch self {
        case let .fetchFailed(error):
            return "Failed to fetch analysis: \(error.localizedDescription)"
        case .analysisTimeout:
            return "Analysis timed out. Please check back later."
        case let .analysisFailed(message):
            return message
        case let .pollingFailed(error):
            return "Failed to get analysis results: \(error.localizedDescription)"
        case .noHealthData:
            return "No health data available for analysis"
        case .insufficientData:
            return "Insufficient data for PAT analysis. Please sync more health data."
        }
    }
}

@Observable
@MainActor
final class PATAnalysisViewModel: BaseViewModel {
    // MARK: - Properties

    private(set) var analysisState: ViewState<PATAnalysisResult> = .idle
    private(set) var analysisHistory: ViewState<[PATAnalysis]> = .idle
    private(set) var isAnalyzing = false

    // MARK: - Dependencies

    private let analyzePATDataUseCase: AnalyzePATDataUseCase
    private let apiClient: APIClientProtocol
    private let patRepository: PATAnalysisRepository
    private let healthRepository: HealthRepository

    // MARK: - Computed Properties

    var currentAnalysis: PATAnalysisResult? {
        analysisState.value
    }

    var hasRecentAnalysis: Bool {
        guard
            let history = analysisHistory.value,
            let latest = history.first else { return false }

        let daysSinceAnalysis = Calendar.current.dateComponents([.day], from: latest.analysisDate ?? Date(), to: Date()).day ?? 0
        return daysSinceAnalysis < 7
    }

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        analyzePATDataUseCase: AnalyzePATDataUseCase,
        apiClient: APIClientProtocol,
        patRepository: PATAnalysisRepository,
        healthRepository: HealthRepository
    ) {
        self.analyzePATDataUseCase = analyzePATDataUseCase
        self.apiClient = apiClient
        self.patRepository = patRepository
        self.healthRepository = healthRepository
        super.init(modelContext: modelContext)
    }

    // MARK: - Public Methods

    func loadAnalysisHistory() async {
        analysisHistory = .loading

        do {
            let analyses = try await patRepository.fetchAll()
            analysisHistory = analyses.isEmpty ? .empty : .loaded(analyses)
        } catch {
            analysisHistory = .error(error)
            handle(error: error)
        }
    }

    func startStepAnalysis() async {
        // Check if we have sufficient health data
        let hasData = await checkHealthDataAvailability()
        guard hasData else {
            analysisState = .error(PATAnalysisError.noHealthData)
            return
        }

        await performAnalysis {
            try await self.analyzePATDataUseCase.executeStepAnalysis()
        }
    }

    func startCustomAnalysis(for analysisId: String) async {
        analysisState = .loading

        do {
            let response = try await apiClient.getPATAnalysis(id: analysisId)
            // Convert [String: Double] to [String: AnyCodable]
            let patFeatures: [String: AnyCodable]? = response.patFeatures?.mapValues { AnyCodable($0) }

            let result = PATAnalysisResult(
                analysisId: response.id,
                status: response.status,
                patFeatures: patFeatures,
                confidence: response.analysis?.confidenceScore,
                completedAt: response.completedAt,
                error: response.errorMessage
            )

            if result.isCompleted {
                analysisState = .loaded(result)
                await saveAnalysisResult(result)
            } else if result.isFailed {
                analysisState = .error(PATAnalysisError.analysisFailed(message: result.error ?? "Analysis failed"))
            } else {
                // Still processing, start polling
                await pollForCompletion(analysisId: analysisId)
            }
        } catch {
            analysisState = .error(PATAnalysisError.fetchFailed(underlying: error))
            handle(error: error)
        }
    }

    func retryAnalysis() async {
        await startStepAnalysis()
    }

    func deleteAnalysis(_ analysis: PATAnalysis) async {
        do {
            try await patRepository.delete(analysis)
            await loadAnalysisHistory()
        } catch {
            handle(error: error)
        }
    }

    // MARK: - Private Methods

    private func performAnalysis(analysisTask: @escaping () async throws -> PATAnalysisResult) async {
        analysisState = .loading
        isAnalyzing = true

        do {
            let result = try await analysisTask()

            if result.isCompleted {
                analysisState = .loaded(result)
                await saveAnalysisResult(result)
            } else if result.isFailed {
                analysisState = .error(PATAnalysisError.analysisFailed(message: result.error ?? "Analysis failed"))
            } else if result.isProcessing {
                // Continue polling for completion
                await pollForCompletion(analysisId: result.analysisId)
            }
        } catch {
            let analysisError = PATAnalysisError.fetchFailed(underlying: error)
            analysisState = .error(analysisError)
            handle(error: analysisError)
        }

        isAnalyzing = false
    }

    private func checkHealthDataAvailability() async -> Bool {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

            let metrics = try await healthRepository.fetchMetrics(for: .steps, since: startDate)

            return metrics.count >= 3 // Need at least 3 days of data
        } catch {
            return false
        }
    }

    private func saveAnalysisResult(_ result: PATAnalysisResult) async {
        let analysis = PATAnalysis(
            startDate: Date().addingTimeInterval(-8 * 60 * 60), // 8 hours ago
            endDate: Date(),
            analysisType: .overnight
        )

        // Set remote ID for sync tracking
        analysis.remoteID = result.analysisId
        analysis.confidenceScore = result.confidence ?? 0
        analysis.syncStatus = result.isCompleted ? .synced : .pending

        // Parse actual PAT features if available
        if let patFeatures = result.patFeatures {
            // Extract sleep metrics from PAT features
            if let sleepEfficiency = patFeatures["sleep_efficiency"]?.value as? Double {
                analysis.sleepEfficiency = sleepEfficiency
            }
            
            if let totalSleepHours = patFeatures["total_sleep_hours"]?.value as? Double {
                analysis.totalSleepMinutes = Int(totalSleepHours * 60)
            } else if let totalSleepMinutes = patFeatures["total_sleep_minutes"]?.value as? Double {
                analysis.totalSleepMinutes = Int(totalSleepMinutes)
            }
            
            // Extract sleep stages if available
            if let deepSleepPercentage = patFeatures["deep_sleep_percentage"]?.value as? Double {
                // Store these percentages for later use
                analysis.deepSleepPercentage = deepSleepPercentage
            }
            
            if let remSleepPercentage = patFeatures["rem_sleep_percentage"]?.value as? Double {
                analysis.remSleepPercentage = remSleepPercentage
            }
            
            if let lightSleepPercentage = patFeatures["light_sleep_percentage"]?.value as? Double {
                analysis.lightSleepPercentage = lightSleepPercentage
            }
        }

        do {
            try await patRepository.create(analysis)
            await loadAnalysisHistory()
        } catch {
            print("Failed to save analysis: \(error)")
        }
    }

    private func pollForCompletion(analysisId: String) async {
        let maxAttempts = 30
        let delaySeconds: UInt64 = 10

        for attempt in 1...maxAttempts {
            do {
                let response = try await apiClient.getPATAnalysis(id: analysisId)
                // Convert [String: Double] to [String: AnyCodable]
                let patFeatures: [String: AnyCodable]? = response.patFeatures?.mapValues { AnyCodable($0) }

                let result = PATAnalysisResult(
                    analysisId: response.id,
                    status: response.status,
                    patFeatures: patFeatures,
                    confidence: response.analysis?.confidenceScore,
                    completedAt: response.completedAt,
                    error: response.errorMessage
                )

                if result.isCompleted {
                    analysisState = .loaded(result)
                    await saveAnalysisResult(result)
                    return
                } else if result.isFailed {
                    analysisState = .error(PATAnalysisError.analysisFailed(message: result.error ?? "Analysis failed"))
                    return
                }

                // Still processing, wait before next check
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                }
            } catch {
                if attempt == maxAttempts {
                    analysisState = .error(PATAnalysisError.pollingFailed(underlying: error))
                }
                // Continue polling on errors except for the last attempt
            }
        }

        // Timeout
        analysisState = .error(PATAnalysisError.analysisTimeout)
    }
}

// MARK: - Supporting Types

extension PATAnalysisViewModel {
    var hasError: Bool {
        switch analysisState {
        case .error:
            true
        default:
            false
        }
    }

    var analysisResult: PATAnalysisResult? {
        switch analysisState {
        case let .loaded(result):
            result
        default:
            nil
        }
    }
}
