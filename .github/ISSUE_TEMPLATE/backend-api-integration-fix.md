---
name: 🚀 Backend API Integration & Contract Adapter Optimization
about: Claude autonomous task to fix backend API integration gaps and optimize contract adapters
title: '🚀 BACKEND: Complete API Integration & Contract Adapter Enhancement'
labels: ['backend', 'api', 'integration', 'autonomous', 'claude']
assignees: []
---

# 🤖 @claude AUTONOMOUS DEVELOPMENT TASK

## 🎯 **MISSION: Complete Backend API Integration & Contract Optimization**

Fix critical backend API integration gaps and optimize contract adapters for seamless frontend-backend communication.

## 🔍 **AUDIT FINDINGS**

### ❌ **CRITICAL INTEGRATION GAPS:**
1. **Incomplete HealthKit upload endpoint integration**
2. **Missing real-time WebSocket connection for health updates**
3. **Contract adapter missing error handling for specific backend scenarios**
4. **Offline queue not properly integrated with all API endpoints**
5. **Missing PAT analysis integration for step data**
6. **Incomplete insight generation API integration**

### 🌐 **BACKEND ENDPOINTS TO INTEGRATE:**

#### Health Data Endpoints:
- `POST /api/v1/healthkit/upload` - HealthKit bulk upload
- `GET /api/v1/healthkit/upload-status/{upload_id}` - Upload status tracking
- `POST /api/v1/health-data/upload` - General health data upload
- `GET /api/v1/health-data/processing/{processing_id}` - Processing status

#### PAT Analysis Endpoints:
- `POST /api/v1/pat/analyze-step-data` - Apple HealthKit step analysis
- `GET /api/v1/pat/analysis/{processing_id}` - PAT analysis results
- `GET /api/v1/pat/models/info` - PAT model information

#### AI Insights Endpoints:
- `POST /api/v1/insights/generate` - Generate health insights
- `GET /api/v1/insights/{insight_id}` - Get cached insight
- `GET /api/v1/insights/history/{user_id}` - Get insight history

#### WebSocket Endpoints:
- `/api/v1/ws/health-analysis/{user_id}` - Real-time health analysis updates

## 🎯 **SPECIFIC FILES TO UPDATE:**

### Core Networking:
- `Core/Networking/BackendAPIClient.swift` - Add missing endpoint implementations
- `Core/Networking/APIClient.swift` - Enhance contract protocols
- `Core/Adapters/BackendContractAdapter.swift` - Add missing response adapters

### Service Layer:
- `Core/Services/HealthKitSyncService.swift` - Integrate new endpoints
- `Core/Services/OfflineQueueManager.swift` - Add queue support for all endpoints
- Create: `Core/Services/WebSocketService.swift` - Real-time communication

### Repository Layer:
- `Data/Repositories/HealthDataRepository.swift` - Add PAT analysis methods
- Create: `Data/Repositories/InsightRepository.swift` - AI insights management

### DTOs:
- Create: `Data/DTOs/PATAnalysisDTOs.swift`
- Create: `Data/DTOs/InsightDTOs.swift`
- Create: `Data/DTOs/WebSocketDTOs.swift`

## 🔧 **TECHNICAL SPECIFICATIONS**

### HealthKit Upload Integration:
```swift
func uploadHealthKitData(samples: [HealthKitSample]) async throws -> HealthKitUploadResponse {
    let dto = HealthKitUploadRequestDTO(samples: samples)
    return try await apiClient.uploadHealthKitData(requestDTO: dto)
}
```

### PAT Analysis Integration:
```swift
func analyzeStepData(stepData: [StepDataPoint]) async throws -> PATAnalysisResponse {
    let dto = PATAnalysisRequestDTO(stepData: stepData, analysisType: "comprehensive")
    return try await apiClient.analyzePATData(requestDTO: dto)
}
```

### WebSocket Integration:
```swift
class WebSocketService {
    func connectToHealthAnalysis(userId: String) async throws
    func subscribeToInsightUpdates() async throws
    func handleRealTimeHealthData(_ data: HealthDataUpdate)
}
```

### Offline Queue Enhancement:
```swift
extension OfflineQueueManager {
    func queueHealthKitUpload(_ request: HealthKitUploadRequestDTO)
    func queuePATAnalysis(_ request: PATAnalysisRequestDTO)
    func queueInsightGeneration(_ request: InsightGenerationRequestDTO)
}
```

## ✅ **SUCCESS CRITERIA**

1. **All backend endpoints integrated** with proper contract adapters
2. **WebSocket service implemented** for real-time updates
3. **Offline queue supports** all new endpoints
4. **PAT analysis fully integrated** with step data pipeline
5. **Insight generation working** end-to-end
6. **Comprehensive error handling** for all API scenarios
7. **Build succeeds** with no compilation errors
8. **All integration tests pass**

## 🚨 **CONSTRAINTS**

- Maintain existing `BackendContractAdapter` pattern
- Follow MVVM + Clean Architecture principles
- Ensure proper error propagation and handling
- Use async/await patterns consistently
- Maintain backward compatibility with existing API calls
- Follow HIPAA compliance for health data transmission

## 📋 **IMPLEMENTATION PHASES**

### Phase 1: Core API Integration
- Implement missing endpoint methods in `BackendAPIClient`
- Add corresponding DTOs for request/response models
- Update contract adapters for new endpoints

### Phase 2: Service Layer Enhancement  
- Integrate new endpoints in `HealthKitSyncService`
- Enhance `OfflineQueueManager` with new endpoint support
- Create `WebSocketService` for real-time communication

### Phase 3: Repository & Testing
- Update repositories with new API methods
- Create comprehensive integration tests
- Add offline scenario testing

## 📝 **DELIVERABLES**

Create a **Pull Request** with:
1. Complete backend API integration for all missing endpoints
2. WebSocket service implementation for real-time updates
3. Enhanced contract adapters with proper error handling
4. Offline queue support for all new endpoints
5. Comprehensive integration tests
6. Updated API documentation

---

**🎯 Priority: HIGH**  
**⏱️ Estimated Effort: High**  
**🤖 Claude Action: Autonomous Implementation Required** 