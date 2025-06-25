# CLARITY Backend-to-Frontend Endpoint Mapping

## Overview
This document provides the exact mapping of all 44 backend endpoints to their frontend implementation. Each endpoint includes request/response structures and implementation patterns.

## Authentication Endpoints (7)

### 1. POST /api/v1/auth/register
**Frontend Implementation:**
```swift
// DTO
struct RegisterRequestDTO: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case email, password
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct RegisterResponseDTO: Codable {
    let userId: String
    let email: String
    let verificationRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case verificationRequired = "verification_required"
    }
}

// Repository Method
func register(email: String, password: String, firstName: String, lastName: String) async throws -> RegisterResponseDTO
```

### 2. POST /api/v1/auth/login
**Frontend Implementation:**
```swift
// DTO
struct LoginRequestDTO: Codable {
    let email: String
    let password: String
}

struct LoginResponseDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}

// Repository Method
func login(email: String, password: String) async throws -> LoginResponseDTO
```

### 3. POST /api/v1/auth/logout
**Frontend Implementation:**
```swift
// No request DTO needed
struct LogoutResponseDTO: Codable {
    let message: String
}

// Repository Method
func logout() async throws
```

### 4. POST /api/v1/auth/refresh
**Frontend Implementation:**
```swift
// DTO
struct RefreshRequestDTO: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct RefreshResponseDTO: Codable {
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

// Repository Method
func refreshToken(_ refreshToken: String) async throws -> RefreshResponseDTO
```

### 5. POST /api/v1/auth/verify
**Frontend Implementation:**
```swift
// DTO
struct VerifyEmailRequestDTO: Codable {
    let email: String
    let verificationCode: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case verificationCode = "verification_code"
    }
}

// Repository Method
func verifyEmail(email: String, code: String) async throws
```

### 6. POST /api/v1/auth/reset-password
**Frontend Implementation:**
```swift
// DTO
struct ResetPasswordRequestDTO: Codable {
    let email: String
}

// Repository Method
func requestPasswordReset(email: String) async throws
```

### 7. GET /api/v1/auth/profile
**Frontend Implementation:**
```swift
// Response DTO
struct UserProfileDTO: Codable {
    let userId: String
    let email: String
    let firstName: String
    let lastName: String
    let createdAt: Date
    let healthDataConnected: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
        case healthDataConnected = "health_data_connected"
    }
}

// Repository Method
func fetchProfile() async throws -> UserProfileDTO
```

## Health Data Endpoints (5)

### 8. POST /api/v1/health-data
**Frontend Implementation:**
```swift
// DTO
struct HealthMetricDTO: Codable {
    let type: String
    let value: Double
    let unit: String
    let timestamp: Date
    let source: String
}

struct UploadHealthDataRequestDTO: Codable {
    let userId: String
    let metrics: [HealthMetricDTO]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case metrics
    }
}

struct ProcessingResponseDTO: Codable {
    let processingId: String
    let status: String
    let metricsCount: Int
    let estimatedCompletion: Date
    
    enum CodingKeys: String, CodingKey {
        case processingId = "processing_id"
        case status
        case metricsCount = "metrics_count"
        case estimatedCompletion = "estimated_completion"
    }
}

// Repository Method
func uploadHealthData(metrics: [HealthMetricDTO]) async throws -> ProcessingResponseDTO
```

### 9. GET /api/v1/health-data/
**Frontend Implementation:**
```swift
// Response DTO
struct PaginatedHealthDataDTO: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let data: [HealthDataItemDTO]
}

struct HealthDataItemDTO: Codable {
    let id: String
    let type: String
    let value: Double
    let timestamp: Date
    let source: String
}

// Repository Method
func fetchHealthData(
    limit: Int = 50,
    offset: Int = 0,
    startDate: Date? = nil,
    endDate: Date? = nil,
    metricType: String? = nil
) async throws -> PaginatedHealthDataDTO
```

### 10. GET /api/v1/health-data/{processing_id}
**Frontend Implementation:**
```swift
// Response DTO
struct ProcessingDetailsDTO: Codable {
    let processingId: String
    let status: String
    let createdAt: Date
    let completedAt: Date?
    let metricsProcessed: Int
    let errors: [String]
    
    enum CodingKeys: String, CodingKey {
        case processingId = "processing_id"
        case status
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case metricsProcessed = "metrics_processed"
        case errors
    }
}

// Repository Method
func getProcessingDetails(processingId: String) async throws -> ProcessingDetailsDTO
```

### 11. DELETE /api/v1/health-data/{processing_id}
**Frontend Implementation:**
```swift
// Repository Method (returns no content - 204)
func deleteProcessingJob(processingId: String) async throws
```

### 12. GET /api/v1/health-data/processing/{id}/status
**Frontend Implementation:**
```swift
// Response DTO
struct ProcessingStatusDTO: Codable {
    let id: String
    let status: String
    let progress: Double
    let estimatedCompletion: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case progress
        case estimatedCompletion = "estimated_completion"
    }
}

// Repository Method
func getProcessingStatus(id: String) async throws -> ProcessingStatusDTO
```

## HealthKit Integration Endpoints (4)

### 13. POST /api/v1/healthkit
**Frontend Implementation:**
```swift
// DTO
struct QuantitySampleDTO: Codable {
    let uuid: String
    let typeIdentifier: String
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case typeIdentifier = "type_identifier"
        case startDate = "start_date"
        case endDate = "end_date"
        case value, unit, source
    }
}

struct CategorySampleDTO: Codable {
    let uuid: String
    let typeIdentifier: String
    let startDate: Date
    let endDate: Date
    let value: Int
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case typeIdentifier = "type_identifier"
        case startDate = "start_date"
        case endDate = "end_date"
        case value, source
    }
}

struct HealthKitDataDTO: Codable {
    let quantitySamples: [QuantitySampleDTO]
    let categorySamples: [CategorySampleDTO]
    
    enum CodingKeys: String, CodingKey {
        case quantitySamples = "quantity_samples"
        case categorySamples = "category_samples"
    }
}

struct HealthKitUploadRequestDTO: Codable {
    let userId: String
    let exportDate: Date
    let data: HealthKitDataDTO
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exportDate = "export_date"
        case data
    }
}

struct HealthKitUploadResponseDTO: Codable {
    let uploadId: String
    let status: String
    let estimatedCompletion: Date
    let samplesReceived: Int
    
    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case status
        case estimatedCompletion = "estimated_completion"
        case samplesReceived = "samples_received"
    }
}

// Repository Method
func uploadHealthKitData(data: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO
```

### 14. GET /api/v1/healthkit/status/{upload_id}
**Frontend Implementation:**
```swift
// Response DTO
struct HealthKitUploadStatusDTO: Codable {
    let uploadId: String
    let status: String
    let progress: Double
    let samplesProcessed: Int
    let patAnalysisReady: Bool
    let insightsGenerated: Bool
    
    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case status
        case progress
        case samplesProcessed = "samples_processed"
        case patAnalysisReady = "pat_analysis_ready"
        case insightsGenerated = "insights_generated"
    }
}

// Repository Method
func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO
```

### 15. POST /api/v1/healthkit/sync
**Frontend Implementation:**
```swift
// Response DTO
struct HealthKitSyncResponseDTO: Codable {
    let syncId: String
    let status: String
    let lastSync: Date?
    
    enum CodingKeys: String, CodingKey {
        case syncId = "sync_id"
        case status
        case lastSync = "last_sync"
    }
}

// Repository Method
func triggerHealthKitSync() async throws -> HealthKitSyncResponseDTO
```

### 16. GET /api/v1/healthkit/categories
**Frontend Implementation:**
```swift
// Response DTOs
struct HealthKitQuantityTypeDTO: Codable {
    let identifier: String
    let displayName: String
    let unit: String
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case identifier
        case displayName = "display_name"
        case unit
        case category
    }
}

struct HealthKitCategoryTypeDTO: Codable {
    let identifier: String
    let displayName: String
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case identifier
        case displayName = "display_name"
        case category
    }
}

struct HealthKitCategoriesResponseDTO: Codable {
    let quantityTypes: [HealthKitQuantityTypeDTO]
    let categoryTypes: [HealthKitCategoryTypeDTO]
    
    enum CodingKeys: String, CodingKey {
        case quantityTypes = "quantity_types"
        case categoryTypes = "category_types"
    }
}

// Repository Method
func getHealthKitCategories() async throws -> HealthKitCategoriesResponseDTO
```

## AI Insights Endpoints (6)

### 17. POST /api/v1/insights
**Frontend Implementation:**
```swift
// Request DTO
struct GenerateInsightRequestDTO: Codable {
    let userId: String
    let type: String
    let dateRange: DateRangeDTO
    let focusAreas: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case dateRange = "date_range"
        case focusAreas = "focus_areas"
    }
}

struct DateRangeDTO: Codable {
    let start: Date
    let end: Date
}

// Response DTO
struct InsightResponseDTO: Codable {
    let insightId: String
    let type: String
    let summary: String
    let recommendations: [String]
    let metrics: [String: AnyCodable]
    let generatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case insightId = "insight_id"
        case type
        case summary
        case recommendations
        case metrics
        case generatedAt = "generated_at"
    }
}

// Repository Method
func generateInsight(
    type: String,
    dateRange: DateRangeDTO,
    focusAreas: [String]
) async throws -> InsightResponseDTO
```

### 18. POST /api/v1/insights/chat
**Frontend Implementation:**
```swift
// Request DTO
struct ChatRequestDTO: Codable {
    let message: String
    let context: ChatContextDTO
}

struct ChatContextDTO: Codable {
    let conversationId: String?
    let focusTimeframe: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case focusTimeframe = "focus_timeframe"
    }
}

// Response DTO
struct ChatResponseDTO: Codable {
    let response: String
    let conversationId: String
    let followUpQuestions: [String]
    let relevantData: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case response
        case conversationId = "conversation_id"
        case followUpQuestions = "follow_up_questions"
        case relevantData = "relevant_data"
    }
}

// Repository Method
func sendChatMessage(
    message: String,
    conversationId: String?,
    focusTimeframe: String?
) async throws -> ChatResponseDTO
```

### 19. GET /api/v1/insights/summary
**Frontend Implementation:**
```swift
// Response DTO
struct InsightSummaryDTO: Codable {
    let period: String
    let date: String
    let summary: String
    let keyInsights: [String]
    let metrics: MetricScoresDTO
    
    enum CodingKeys: String, CodingKey {
        case period
        case date
        case summary
        case keyInsights = "key_insights"
        case metrics
    }
}

struct MetricScoresDTO: Codable {
    let sleepScore: Int?
    let activityScore: Int?
    let recoveryScore: Int?
    
    enum CodingKeys: String, CodingKey {
        case sleepScore = "sleep_score"
        case activityScore = "activity_score"
        case recoveryScore = "recovery_score"
    }
}

// Repository Method
func getInsightSummary(
    period: String,
    date: Date
) async throws -> InsightSummaryDTO
```

### 20. GET /api/v1/insights/recommendations
**Frontend Implementation:**
```swift
// Response DTO
struct RecommendationDTO: Codable {
    let category: String
    let priority: String
    let title: String
    let description: String
    let actionableSteps: [String]
    
    enum CodingKeys: String, CodingKey {
        case category
        case priority
        case title
        case description
        case actionableSteps = "actionable_steps"
    }
}

struct RecommendationsResponseDTO: Codable {
    let recommendations: [RecommendationDTO]
    let generatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case generatedAt = "generated_at"
    }
}

// Repository Method
func getRecommendations() async throws -> RecommendationsResponseDTO
```

### 21. GET /api/v1/insights/trends
**Frontend Implementation:**
```swift
// Response DTO
struct TrendDataPointDTO: Codable {
    let date: String
    let value: Double
    let qualityScore: Int?
    
    enum CodingKeys: String, CodingKey {
        case date
        case value
        case qualityScore = "quality_score"
    }
}

struct TrendsResponseDTO: Codable {
    let metric: String
    let timeframe: String
    let trend: String
    let changePercentage: Double
    let analysis: String
    let dataPoints: [TrendDataPointDTO]
    
    enum CodingKeys: String, CodingKey {
        case metric
        case timeframe
        case trend
        case changePercentage = "change_percentage"
        case analysis
        case dataPoints = "data_points"
    }
}

// Repository Method
func getTrends(
    metric: String,
    timeframe: String
) async throws -> TrendsResponseDTO
```

### 22. GET /api/v1/insights/alerts
**Frontend Implementation:**
```swift
// Response DTO
struct AlertDTO: Codable {
    let id: String
    let type: String
    let category: String
    let message: String
    let severity: String
    let createdAt: Date
    let actionable: Bool
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case category
        case message
        case severity
        case createdAt = "created_at"
        case actionable
        case recommendations
    }
}

struct AlertsResponseDTO: Codable {
    let alerts: [AlertDTO]
}

// Repository Method
func getAlerts() async throws -> AlertsResponseDTO
```

## PAT Analysis Endpoints (5)

### 23. POST /api/v1/pat/analysis
**Frontend Implementation:**
```swift
// Request DTO
struct PATAnalysisRequestDTO: Codable {
    let userId: String
    let dataSource: String
    let analysisType: String
    let timeframe: TimeframeDTO
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case dataSource = "data_source"
        case analysisType = "analysis_type"
        case timeframe
    }
}

struct TimeframeDTO: Codable {
    let start: Date
    let end: Date
}

// Response DTO
struct PATAnalysisResponseDTO: Codable {
    let analysisId: String
    let status: String
    let estimatedCompletion: Date
    let modelVersion: String
    
    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case status
        case estimatedCompletion = "estimated_completion"
        case modelVersion = "model_version"
    }
}

// Repository Method
func startPATAnalysis(
    dataSource: String,
    analysisType: String,
    timeframe: TimeframeDTO
) async throws -> PATAnalysisResponseDTO
```

### 24. GET /api/v1/pat/status/{analysis_id}
**Frontend Implementation:**
```swift
// Response DTO
struct PATAnalysisStatusDTO: Codable {
    let analysisId: String
    let status: String
    let progress: Double
    let startedAt: Date
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case status
        case progress
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

// Repository Method
func getPATAnalysisStatus(analysisId: String) async throws -> PATAnalysisStatusDTO
```

### 25. GET /api/v1/pat/results/{analysis_id}
**Frontend Implementation:**
```swift
// Response DTOs
struct SleepStageDTO: Codable {
    let start: Date
    let stage: String
    let confidence: Double
}

struct AnomalyDTO: Codable {
    let timestamp: Date
    let type: String
    let severity: String
}

struct PATResultsDTO: Codable {
    let sleepQualityScore: Double
    let circadianRhythmStability: Double
    let sleepEfficiency: Double
    let predictedSleepStages: [SleepStageDTO]
    let anomalies: [AnomalyDTO]
    
    enum CodingKeys: String, CodingKey {
        case sleepQualityScore = "sleep_quality_score"
        case circadianRhythmStability = "circadian_rhythm_stability"
        case sleepEfficiency = "sleep_efficiency"
        case predictedSleepStages = "predicted_sleep_stages"
        case anomalies
    }
}

struct ModelMetadataDTO: Codable {
    let version: String
    let confidence: Double
    let dataQuality: String
    
    enum CodingKeys: String, CodingKey {
        case version
        case confidence
        case dataQuality = "data_quality"
    }
}

struct PATAnalysisResultsResponseDTO: Codable {
    let analysisId: String
    let results: PATResultsDTO
    let modelMetadata: ModelMetadataDTO
    
    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case results
        case modelMetadata = "model_metadata"
    }
}

// Repository Method
func getPATAnalysisResults(analysisId: String) async throws -> PATAnalysisResultsResponseDTO
```

### 26. POST /api/v1/pat/batch
**Frontend Implementation:**
```swift
// Request DTO
struct BatchAnalysisItemDTO: Codable {
    let userId: String
    let timeframe: TimeframeDTO
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timeframe
    }
}

struct BatchPATAnalysisRequestDTO: Codable {
    let analyses: [BatchAnalysisItemDTO]
}

// Response DTO
struct BatchPATAnalysisResponseDTO: Codable {
    let batchId: String
    let analysesQueued: Int
    let estimatedCompletion: Date
    
    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case analysesQueued = "analyses_queued"
        case estimatedCompletion = "estimated_completion"
    }
}

// Repository Method
func startBatchPATAnalysis(analyses: [BatchAnalysisItemDTO]) async throws -> BatchPATAnalysisResponseDTO
```

### 27. GET /api/v1/pat/models
**Frontend Implementation:**
```swift
// Response DTO
struct PATModelDTO: Codable {
    let version: String
    let name: String
    let description: String
    let accuracy: Double
    let isDefault: Bool
    
    enum CodingKeys: String, CodingKey {
        case version
        case name
        case description
        case accuracy
        case isDefault = "is_default"
    }
}

struct PATModelsResponseDTO: Codable {
    let models: [PATModelDTO]
}

// Repository Method
func getPATModels() async throws -> PATModelsResponseDTO
```

## Metrics & Monitoring Endpoints (4)

### 28. GET /api/v1/metrics/health
**Frontend Implementation:**
```swift
// Response DTO
struct ServiceHealthDTO: Codable {
    let database: String
    let aiModels: String
    let externalApis: String
    
    enum CodingKeys: String, CodingKey {
        case database
        case aiModels = "ai_models"
        case externalApis = "external_apis"
    }
}

struct PerformanceMetricsDTO: Codable {
    let avgResponseTimeMs: Int
    let requestsPerMinute: Int
    
    enum CodingKeys: String, CodingKey {
        case avgResponseTimeMs = "avg_response_time_ms"
        case requestsPerMinute = "requests_per_minute"
    }
}

struct SystemHealthDTO: Codable {
    let status: String
    let uptimeSeconds: Int
    let version: String
    let services: ServiceHealthDTO
    let performance: PerformanceMetricsDTO
    
    enum CodingKeys: String, CodingKey {
        case status
        case uptimeSeconds = "uptime_seconds"
        case version
        case services
        case performance
    }
}

// Repository Method
func getSystemHealth() async throws -> SystemHealthDTO
```

### 29. GET /api/v1/metrics/user/{user_id}
**Frontend Implementation:**
```swift
// Response DTOs
struct DataSummaryDTO: Codable {
    let totalDataPoints: Int
    let daysOfData: Int
    let lastUpload: Date
    
    enum CodingKeys: String, CodingKey {
        case totalDataPoints = "total_data_points"
        case daysOfData = "days_of_data"
        case lastUpload = "last_upload"
    }
}

struct AnalysisSummaryDTO: Codable {
    let patAnalysesCompleted: Int
    let insightsGenerated: Int
    let avgProcessingTimeSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case patAnalysesCompleted = "pat_analyses_completed"
        case insightsGenerated = "insights_generated"
        case avgProcessingTimeSeconds = "avg_processing_time_seconds"
    }
}

struct UserMetricsDTO: Codable {
    let userId: String
    let dataSummary: DataSummaryDTO
    let analysisSummary: AnalysisSummaryDTO
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case dataSummary = "data_summary"
        case analysisSummary = "analysis_summary"
    }
}

// Repository Method
func getUserMetrics(userId: String) async throws -> UserMetricsDTO
```

### 30. POST /api/v1/metrics/export
**Frontend Implementation:**
```swift
// Request DTO
struct ExportRequestDTO: Codable {
    let format: String
    let dateRange: DateRangeDTO
    let metricTypes: [String]
    
    enum CodingKeys: String, CodingKey {
        case format
        case dateRange = "date_range"
        case metricTypes = "metric_types"
    }
}

// Response DTO
struct ExportResponseDTO: Codable {
    let exportId: String
    let downloadUrl: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case exportId = "export_id"
        case downloadUrl = "download_url"
        case expiresAt = "expires_at"
    }
}

// Repository Method
func exportMetrics(
    format: String,
    dateRange: DateRangeDTO,
    metricTypes: [String]
) async throws -> ExportResponseDTO
```

### 31. GET /metrics (Prometheus)
**Note:** This is a Prometheus metrics endpoint - not typically called from mobile app

## WebSocket Endpoints (3)

### 32. WS /api/v1/ws
**Frontend Implementation:**
```swift
// WebSocket Message Types
enum WebSocketMessageType: String, Codable {
    case subscribe
    case healthData = "health_data"
    case chatMessage = "chat_message"
}

// Subscribe Message
struct SubscribeMessage: Codable {
    let type: WebSocketMessageType
    let channel: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case userId = "user_id"
    }
}

// Health Data Message
struct HealthDataMessage: Codable {
    let type: WebSocketMessageType
    let data: HealthDataPayload
}

struct HealthDataPayload: Codable {
    let heartRate: Double?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case heartRate = "heart_rate"
        case timestamp
    }
}

// Chat Message
struct ChatWebSocketMessage: Codable {
    let type: WebSocketMessageType
    let message: String
    let conversationId: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case message
        case conversationId = "conversation_id"
    }
}

// WebSocket Manager Methods
func connect(authToken: String) async throws
func subscribe(to channel: String) async throws
func sendMessage(_ message: Codable) async throws
func disconnect()
```

### 33. GET /api/v1/ws/health
**Frontend Implementation:**
```swift
// Response DTO
struct WebSocketHealthDTO: Codable {
    let websocketStatus: String
    let activeConnections: Int
    let avgMessageLatencyMs: Int
    
    enum CodingKeys: String, CodingKey {
        case websocketStatus = "websocket_status"
        case activeConnections = "active_connections"
        case avgMessageLatencyMs = "avg_message_latency_ms"
    }
}

// Repository Method
func getWebSocketHealth() async throws -> WebSocketHealthDTO
```

### 34. GET /api/v1/ws/rooms
**Frontend Implementation:**
```swift
// Response DTOs
struct WebSocketRoomDTO: Codable {
    let id: String
    let description: String
    let activeUsers: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case activeUsers = "active_users"
    }
}

struct WebSocketRoomsResponseDTO: Codable {
    let rooms: [WebSocketRoomDTO]
}

// Repository Method
func getWebSocketRooms() async throws -> WebSocketRoomsResponseDTO
```

## System Endpoints (4)

### 35. GET /health
**Frontend Implementation:**
```swift
// Response DTO
struct HealthCheckDTO: Codable {
    let status: String
    let service: String
    let version: String
    let timestamp: Date
}

// Repository Method
func healthCheck() async throws -> HealthCheckDTO
```

### 36-38. Documentation Endpoints
- GET /docs (Swagger UI)
- GET /redoc (ReDoc)
- GET /openapi.json

**Note:** These are documentation endpoints not typically called from the app

### 39. GET / (Root)
**Frontend Implementation:**
```swift
// Response DTO
struct RootResponseDTO: Codable {
    let name: String
    let version: String
    let status: String
    let totalEndpoints: Int
    let apiDocs: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case version
        case status
        case totalEndpoints = "total_endpoints"
        case apiDocs = "api_docs"
    }
}

// Repository Method
func getRootInfo() async throws -> RootResponseDTO
```

## Error Response Structure

All endpoints return errors in this format:

```swift
struct APIErrorResponseDTO: Codable {
    let error: ErrorDetailsDTO
    let requestId: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case error
        case requestId = "request_id"
        case timestamp
    }
}

struct ErrorDetailsDTO: Codable {
    let code: String
    let message: String
    let details: [String: AnyCodable]?
}
```

## Common Headers

All authenticated endpoints require:
```swift
Authorization: Bearer <jwt_token>
```

All requests should include:
```swift
Content-Type: application/json
Accept: application/json
```

## Testing Each Endpoint

For each endpoint:
1. Write DTO encoding/decoding tests
2. Write repository method tests with mocks
3. Write integration tests with mock server
4. Test error cases (401, 403, 404, 422, 500)
5. Test network timeout scenarios

---

*This mapping is complete and exact. Use it as the source of truth for implementation.*