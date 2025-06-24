import Foundation
@testable import clarity_loop_frontend

@MainActor
class MockInsightsRepositoryProtocol: InsightsRepositoryProtocol {
    // MARK: - Mock State
    var generateInsightCalled = false
    var getHistoryCalled = false
    
    // MARK: - Captured Parameters
    var capturedGenerateRequest: InsightGenerationRequestDTO?
    var capturedUserId: String?
    var capturedLimit: Int?
    var capturedOffset: Int?
    
    // MARK: - Mock Responses
    var insightToGenerate: InsightGenerationResponseDTO?
    var historyToReturn: InsightHistoryResponseDTO?
    var shouldFail = false
    var mockError = NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    // MARK: - InsightsRepositoryProtocol Methods
    
    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        generateInsightCalled = true
        capturedGenerateRequest = requestDTO
        
        if shouldFail {
            throw mockError
        }
        
        guard let response = insightToGenerate else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock response configured"])
        }
        
        return response
    }
    
    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        getHistoryCalled = true
        capturedUserId = userId
        capturedLimit = limit
        capturedOffset = offset
        
        if shouldFail {
            throw mockError
        }
        
        guard let response = historyToReturn else {
            // Return empty history if not configured
            return InsightHistoryResponseDTO(
                success: true,
                data: InsightHistoryDataDTO(
                    insights: [],
                    totalCount: 0,
                    hasMore: false,
                    pagination: nil
                ),
                metadata: nil
            )
        }
        
        return response
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        generateInsightCalled = false
        getHistoryCalled = false
        
        capturedGenerateRequest = nil
        capturedUserId = nil
        capturedLimit = nil
        capturedOffset = nil
        
        insightToGenerate = nil
        historyToReturn = nil
        shouldFail = false
    }
}