import Foundation
@testable import clarity_loop_frontend

// MARK: - Additional Properties for MockAPIClient
// This file provides handler properties and utility methods for MockAPIClient
// The actual method implementations are in the main MockAPIClient class

extension MockAPIClient {
    // Singleton to store handlers
    private static var handlers = Handlers()
    
    private struct Handlers {
        var getHealthDataHandler: ((Int, Int) async throws -> PaginatedMetricsResponseDTO)?
        var syncHealthKitDataHandler: ((HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO)?
        var getHealthKitSyncStatusHandler: ((String) async throws -> HealthKitSyncStatusDTO)?
        var getHealthKitUploadStatusHandler: ((String) async throws -> HealthKitUploadStatusDTO)?
        var getProcessingStatusHandler: ((UUID) async throws -> HealthDataProcessingStatusDTO)?
        var analyzeStepDataHandler: ((StepDataRequestDTO) async throws -> StepAnalysisResponseDTO)?
        var analyzeActigraphyHandler: ((DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO)?
        var getPATAnalysisHandler: ((String) async throws -> PATAnalysisResponseDTO)?
    }
    
    // Handler properties
    var getHealthDataHandler: ((Int, Int) async throws -> PaginatedMetricsResponseDTO)? {
        get { MockAPIClient.handlers.getHealthDataHandler }
        set { MockAPIClient.handlers.getHealthDataHandler = newValue }
    }
    
    var syncHealthKitDataHandler: ((HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO)? {
        get { MockAPIClient.handlers.syncHealthKitDataHandler }
        set { MockAPIClient.handlers.syncHealthKitDataHandler = newValue }
    }
    
    var getHealthKitSyncStatusHandler: ((String) async throws -> HealthKitSyncStatusDTO)? {
        get { MockAPIClient.handlers.getHealthKitSyncStatusHandler }
        set { MockAPIClient.handlers.getHealthKitSyncStatusHandler = newValue }
    }
    
    var getHealthKitUploadStatusHandler: ((String) async throws -> HealthKitUploadStatusDTO)? {
        get { MockAPIClient.handlers.getHealthKitUploadStatusHandler }
        set { MockAPIClient.handlers.getHealthKitUploadStatusHandler = newValue }
    }
    
    var getProcessingStatusHandler: ((UUID) async throws -> HealthDataProcessingStatusDTO)? {
        get { MockAPIClient.handlers.getProcessingStatusHandler }
        set { MockAPIClient.handlers.getProcessingStatusHandler = newValue }
    }
    
    var analyzeStepDataHandler: ((StepDataRequestDTO) async throws -> StepAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.analyzeStepDataHandler }
        set { MockAPIClient.handlers.analyzeStepDataHandler = newValue }
    }
    
    var analyzeActigraphyHandler: ((DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.analyzeActigraphyHandler }
        set { MockAPIClient.handlers.analyzeActigraphyHandler = newValue }
    }
    
    var getPATAnalysisHandler: ((String) async throws -> PATAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.getPATAnalysisHandler }
        set { MockAPIClient.handlers.getPATAnalysisHandler = newValue }
    }
    
    // Reset all handlers
    static func resetHandlers() {
        handlers = Handlers()
    }
}