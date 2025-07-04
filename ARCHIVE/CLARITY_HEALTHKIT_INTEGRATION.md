# CLARITY HealthKit Integration & Apple Watch Sync Guide

## Overview
This guide provides comprehensive documentation for integrating HealthKit into CLARITY Pulse V2, with a focus on Apple Watch data synchronization, background delivery, and HIPAA-compliant data handling.

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Authorization Flow](#authorization-flow)
3. [Apple Watch Integration](#apple-watch-integration)
4. [Data Types & Categories](#data-types--categories)
5. [Background Sync](#background-sync)
6. [Implementation Guide](#implementation-guide)
7. [Testing Strategy](#testing-strategy)
8. [HIPAA Compliance](#hipaa-compliance)

## Core Concepts

### HealthKit Architecture
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Apple Watch   │────▶│   HealthKit     │────▶│  CLARITY App    │
│   (Data Source) │     │   (Central DB)   │     │   (Consumer)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                         │
         │                       ▼                         ▼
         │              ┌─────────────────┐      ┌─────────────────┐
         └─────────────▶│   Health App    │      │  Backend API    │
                        │    (Viewer)      │      │   (Storage)     │
                        └─────────────────┘      └─────────────────┘
```

### Key Principles
1. **User Privacy First**: Always request minimum necessary permissions
2. **Transparent Data Usage**: Clear explanations of why each data type is needed
3. **Fail Gracefully**: App must work even without HealthKit access
4. **Efficient Syncing**: Batch operations and smart queries
5. **Background Updates**: Keep data fresh without draining battery

## Authorization Flow

### 1. Setup HealthKit Capability
First, ensure HealthKit is enabled in your project:
- Target → Signing & Capabilities → + Capability → HealthKit
- Check "Background Delivery" for Apple Watch sync

### 2. Info.plist Requirements
```xml
<key>NSHealthShareUsageDescription</key>
<string>CLARITY needs access to your health data to provide personalized insights and track your wellness journey. Your data is encrypted and never shared without your permission.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>CLARITY can record health data from manual entries and connected devices to maintain a complete health record.</string>

<!-- iOS 18+ Mental Health -->
<key>NSHealthMentalWellbeingUsageDescription</key>
<string>CLARITY can track your mental wellbeing to provide holistic health insights combining physical and mental health data.</string>
```

### 3. HealthKit Manager Implementation

```swift
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var isHealthKitAvailable: Bool = false
    
    // MARK: - Data Types
    private let readTypes: Set<HKSampleType> = [
        // Vital Signs
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.walkingHeartRateAverage),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.bloodPressureSystolic),
        HKQuantityType(.bloodPressureDiastolic),
        HKQuantityType(.bodyTemperature),
        
        // Activity
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.appleStandTime),
        HKQuantityType(.appleMoveTime),
        
        // Body Measurements
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyMassIndex),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.leanBodyMass),
        HKQuantityType(.waistCircumference),
        
        // Sleep
        HKCategoryType(.sleepAnalysis),
        
        // Nutrition
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.dietaryProtein),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryFatTotal),
        HKQuantityType(.dietaryWater),
        
        // iOS 18+ Mental Wellbeing
        HKCategoryType(.stateOfMind),
        HKQuantityType(.depressionRiskScore),
        HKQuantityType(.anxietyRiskScore),
        
        // Workouts
        HKObjectType.workoutType(),
        
        // Clinical Records (if available)
        HKClinicalType.clinicalType(forIdentifier: .allergyRecord),
        HKClinicalType.clinicalType(forIdentifier: .conditionRecord),
        HKClinicalType.clinicalType(forIdentifier: .immunizationRecord),
        HKClinicalType.clinicalType(forIdentifier: .labResultRecord),
        HKClinicalType.clinicalType(forIdentifier: .medicationRecord),
        HKClinicalType.clinicalType(forIdentifier: .procedureRecord),
        HKClinicalType.clinicalType(forIdentifier: .vitalSignRecord)
    ].compactMap { $0 }
    
    private let writeTypes: Set<HKSampleType> = [
        // Manual entry types
        HKQuantityType(.bodyMass),
        HKQuantityType(.bloodPressureSystolic),
        HKQuantityType(.bloodPressureDiastolic),
        HKQuantityType(.bloodGlucose),
        HKQuantityType(.dietaryWater),
        HKCategoryType(.stateOfMind)
    ].compactMap { $0 }
    
    // MARK: - Initialization
    init() {
        checkHealthKitAvailability()
    }
    
    // MARK: - Authorization
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
    }
    
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        do {
            try await healthStore.requestAuthorization(
                toShare: writeTypes,
                read: readTypes
            )
            
            await MainActor.run {
                updateAuthorizationStatus()
            }
            
            // Setup background delivery after authorization
            await setupBackgroundDelivery()
            
        } catch {
            throw HealthKitError.authorizationFailed(error)
        }
    }
    
    private func updateAuthorizationStatus() {
        // Check authorization for a representative type
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            authorizationStatus = .notDetermined
            return
        }
        
        switch healthStore.authorizationStatus(for: heartRateType) {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .sharingAuthorized:
            authorizationStatus = .authorized
        case .sharingDenied:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }
}
```

## Apple Watch Integration

### 1. Watch App Architecture
```swift
// MARK: - Watch App Health Manager
import HealthKit
import WatchKit

class WatchHealthManager: NSObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // MARK: - Real-time Data Collection
    func startWorkoutSession(workoutType: HKWorkoutActivityType) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            builder = workoutSession?.associatedWorkoutBuilder()
            
            // Setup data sources
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start collecting data
            workoutSession?.startActivity(with: Date())
            try await builder?.beginCollection(at: Date())
            
        } catch {
            throw HealthKitError.workoutSessionFailed(error)
        }
    }
    
    // MARK: - Background Heart Rate Monitoring
    func enableBackgroundHeartRateDelivery() async throws {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        try await healthStore.enableBackgroundDelivery(
            for: heartRateType,
            frequency: .immediate
        ) { success, error in
            if !success {
                print("Failed to enable background delivery: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
```

### 2. Data Sync Strategy

```swift
// MARK: - Sync Coordinator
actor HealthDataSyncCoordinator {
    private let healthStore = HKHealthStore()
    private let backend: HealthBackendService
    private var syncQueue: [HealthDataBatch] = []
    private var isSyncing = false
    
    // MARK: - Batch Processing
    struct HealthDataBatch {
        let id: UUID
        let samples: [HKSample]
        let source: DataSource
        let priority: SyncPriority
        
        enum DataSource {
            case appleWatch
            case iPhone
            case manual
        }
        
        enum SyncPriority: Int {
            case immediate = 0  // Real-time vitals
            case high = 1       // Recent data
            case normal = 2     // Historical data
            case low = 3        // Bulk imports
        }
    }
    
    // MARK: - Intelligent Sync
    func syncHealthData(from startDate: Date, to endDate: Date) async throws {
        // 1. Fetch new samples
        let samples = try await fetchNewSamples(from: startDate, to: endDate)
        
        // 2. Group by type and source
        let batches = createBatches(from: samples)
        
        // 3. Add to sync queue with priority
        for batch in batches {
            await addToSyncQueue(batch)
        }
        
        // 4. Process queue
        await processSyncQueue()
    }
    
    private func fetchNewSamples(from startDate: Date, to endDate: Date) async throws -> [HKSample] {
        var allSamples: [HKSample] = []
        
        // Fetch each data type
        for sampleType in readTypes {
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            
            let samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: sampleType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            allSamples.append(contentsOf: samples)
        }
        
        return allSamples
    }
    
    private func createBatches(from samples: [HKSample]) -> [HealthDataBatch] {
        // Group by source device
        let groupedBySource = Dictionary(grouping: samples) { sample in
            sample.sourceRevision.source.bundleIdentifier
        }
        
        return groupedBySource.compactMap { (source, samples) in
            let dataSource: HealthDataBatch.DataSource = {
                if source.contains("Watch") {
                    return .appleWatch
                } else if source.contains("Health") {
                    return .iPhone
                } else {
                    return .manual
                }
            }()
            
            // Determine priority based on data freshness
            let priority: HealthDataBatch.SyncPriority = {
                let hoursSinceCollection = Date().timeIntervalSince(samples.first?.startDate ?? Date()) / 3600
                
                if hoursSinceCollection < 1 {
                    return .immediate
                } else if hoursSinceCollection < 24 {
                    return .high
                } else if hoursSinceCollection < 168 { // 1 week
                    return .normal
                } else {
                    return .low
                }
            }()
            
            return HealthDataBatch(
                id: UUID(),
                samples: samples,
                source: dataSource,
                priority: priority
            )
        }
    }
    
    private func processSyncQueue() async {
        guard !isSyncing else { return }
        isSyncing = true
        
        defer { isSyncing = false }
        
        // Sort by priority
        let sortedQueue = syncQueue.sorted { $0.priority.rawValue < $1.priority.rawValue }
        
        for batch in sortedQueue {
            do {
                try await uploadBatch(batch)
                // Remove from queue after successful upload
                syncQueue.removeAll { $0.id == batch.id }
            } catch {
                // Handle retry logic
                print("Failed to sync batch \(batch.id): \(error)")
            }
        }
    }
}
```

### 3. Background Delivery Setup

```swift
extension HealthKitManager {
    // MARK: - Background Delivery
    private func setupBackgroundDelivery() async {
        // High-priority types for immediate delivery
        let immediateTypes: [HKQuantityType] = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate)
        ].compactMap { $0 }
        
        // Normal priority types for hourly delivery
        let hourlyTypes: [HKQuantityType] = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ].compactMap { $0 }
        
        // Enable immediate delivery for critical vitals
        for type in immediateTypes {
            do {
                try await healthStore.enableBackgroundDelivery(
                    for: type,
                    frequency: .immediate
                )
            } catch {
                print("Failed to enable background delivery for \(type): \(error)")
            }
        }
        
        // Enable hourly delivery for activity data
        for type in hourlyTypes {
            do {
                try await healthStore.enableBackgroundDelivery(
                    for: type,
                    frequency: .hourly
                )
            } catch {
                print("Failed to enable background delivery for \(type): \(error)")
            }
        }
    }
    
    // MARK: - Background Task Handler
    func handleBackgroundDelivery(for type: HKSampleType) async {
        // This method is called when new data is available
        let lastSync = UserDefaults.standard.object(forKey: "lastSync_\(type.identifier)") as? Date ?? Date.distantPast
        
        do {
            // Fetch only new samples since last sync
            let samples = try await fetchSamples(
                for: type,
                from: lastSync,
                to: Date()
            )
            
            if !samples.isEmpty {
                // Upload to backend
                try await uploadSamples(samples)
                
                // Update last sync timestamp
                UserDefaults.standard.set(Date(), forKey: "lastSync_\(type.identifier)")
            }
        } catch {
            print("Background sync failed for \(type): \(error)")
        }
    }
}
```

## Data Types & Categories

### 1. Vital Signs Monitoring
```swift
struct VitalSignsMonitor {
    let healthStore: HKHealthStore
    
    // MARK: - Heart Rate with Context
    func fetchHeartRateWithContext(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let readings = (samples ?? []).compactMap { sample -> HeartRateReading? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    
                    let bpm = quantitySample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                    
                    // Determine context from metadata
                    let context = determineHeartRateContext(from: quantitySample)
                    
                    return HeartRateReading(
                        timestamp: quantitySample.startDate,
                        value: bpm,
                        context: context,
                        source: quantitySample.sourceRevision.source.name ?? "Unknown",
                        metadata: quantitySample.metadata
                    )
                }
                
                continuation.resume(returning: readings)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func determineHeartRateContext(from sample: HKQuantitySample) -> HeartRateContext {
        // Check workout context
        if let workoutType = sample.metadata?[HKMetadataKeyWorkoutBrandName] as? String {
            return .workout(type: workoutType)
        }
        
        // Check motion context
        if let motionContext = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber {
            switch motionContext.intValue {
            case 1:
                return .resting
            case 2:
                return .active
            case 3:
                return .workout(type: "Unknown")
            default:
                return .unknown
            }
        }
        
        // Check if it's a resting measurement
        if sample.metadata?[HKMetadataKeyHeartRateRecoveryTestType] != nil {
            return .recovery
        }
        
        return .unknown
    }
}

struct HeartRateReading {
    let timestamp: Date
    let value: Double
    let context: HeartRateContext
    let source: String
    let metadata: [String: Any]?
}

enum HeartRateContext {
    case resting
    case active
    case workout(type: String)
    case recovery
    case unknown
}
```

### 2. Sleep Analysis (iOS 16+)
```swift
struct SleepAnalyzer {
    let healthStore: HKHealthStore
    
    func fetchSleepAnalysis(from startDate: Date, to endDate: Date) async throws -> SleepSummary {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let samples = try await fetchSamples(of: sleepType, predicate: predicate)
        
        // Process sleep stages
        let sleepStages = samples.compactMap { sample -> SleepStage? in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            
            let stage: SleepStageType = {
                switch categorySample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    return .inBed
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    return .asleep
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    return .awake
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    return .core
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    return .deep
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    return .rem
                default:
                    return .unknown
                }
            }()
            
            return SleepStage(
                startTime: categorySample.startDate,
                endTime: categorySample.endDate,
                stage: stage,
                source: categorySample.sourceRevision.source.name ?? "Unknown"
            )
        }
        
        return analyzeSleepStages(sleepStages)
    }
    
    private func analyzeSleepStages(_ stages: [SleepStage]) -> SleepSummary {
        // Calculate total sleep time, efficiency, etc.
        let totalSleepTime = stages
            .filter { $0.stage != .inBed && $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
        
        let totalInBedTime = stages
            .filter { $0.stage == .inBed }
            .reduce(0) { $0 + $1.duration }
        
        let efficiency = totalInBedTime > 0 ? (totalSleepTime / totalInBedTime) * 100 : 0
        
        return SleepSummary(
            totalSleepTime: totalSleepTime,
            totalInBedTime: totalInBedTime,
            efficiency: efficiency,
            stages: stages,
            heartRateDuringSleep: nil // Fetch separately if needed
        )
    }
}
```

### 3. iOS 18 Mental Wellbeing
```swift
struct MentalWellbeingTracker {
    let healthStore: HKHealthStore
    
    // MARK: - State of Mind Logging
    func logStateOfMind(_ state: StateOfMind) async throws {
        guard let stateOfMindType = HKCategoryType.categoryType(forIdentifier: .stateOfMind) else {
            throw HealthKitError.invalidType
        }
        
        let sample = HKCategorySample(
            type: stateOfMindType,
            value: state.hkValue,
            start: Date(),
            end: Date(),
            metadata: [
                "mood_rating": state.rating,
                "emotions": state.emotions.map { $0.rawValue },
                "notes": state.notes ?? ""
            ]
        )
        
        try await healthStore.save(sample)
    }
    
    // MARK: - Mental Health Risk Scores
    func fetchMentalHealthRiskScores() async throws -> MentalHealthRiskAssessment {
        let depressionScore = try await fetchLatestScore(for: .depressionRiskScore)
        let anxietyScore = try await fetchLatestScore(for: .anxietyRiskScore)
        
        return MentalHealthRiskAssessment(
            depressionRisk: depressionScore,
            anxietyRisk: anxietyScore,
            assessmentDate: Date()
        )
    }
    
    private func fetchLatestScore(for identifier: HKQuantityTypeIdentifier) async throws -> RiskScore? {
        guard let scoreType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: scoreType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let score = sample.quantity.doubleValue(for: .percent())
                let risk: RiskLevel = {
                    switch score {
                    case 0..<0.3: return .low
                    case 0.3..<0.7: return .moderate
                    default: return .high
                    }
                }()
                
                continuation.resume(returning: RiskScore(
                    value: score,
                    level: risk,
                    date: sample.startDate
                ))
            }
            
            healthStore.execute(query)
        }
    }
}

struct StateOfMind {
    let rating: Int // 1-10
    let emotions: [Emotion]
    let notes: String?
    
    var hkValue: Int {
        // Map to HealthKit category values
        switch rating {
        case 1...3: return 1  // Negative
        case 4...6: return 2  // Neutral
        case 7...10: return 3 // Positive
        default: return 2
        }
    }
    
    enum Emotion: String {
        case happy, sad, anxious, calm, energetic, tired, stressed, relaxed
    }
}
```

## Background Sync

### 1. Background Task Registration
```swift
// In AppDelegate or App
import BackgroundTasks

func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.clarity.healthsync",
        using: nil
    ) { task in
        handleHealthSync(task: task as! BGProcessingTask)
    }
    
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.clarity.vitalsrefresh",
        using: nil
    ) { task in
        handleVitalsRefresh(task: task as! BGAppRefreshTask)
    }
}

func scheduleHealthSync() {
    let request = BGProcessingTaskRequest(identifier: "com.clarity.healthsync")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1 hour
    
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Failed to schedule health sync: \(error)")
    }
}

func handleHealthSync(task: BGProcessingTask) {
    let syncTask = Task {
        do {
            // Perform sync
            let coordinator = HealthDataSyncCoordinator()
            try await coordinator.performFullSync()
            
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
    
    task.expirationHandler = {
        syncTask.cancel()
    }
}
```

### 2. Efficient Query Strategies
```swift
extension HealthKitManager {
    // MARK: - Anchored Object Query for Incremental Updates
    func setupContinuousMonitoring(for type: HKSampleType) {
        var anchor: HKQueryAnchor? = loadAnchor(for: type)
        
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Anchored query error: \(error)")
                return
            }
            
            // Process new samples
            if let samples = samples, !samples.isEmpty {
                Task {
                    await self.processSamples(samples, for: type)
                }
            }
            
            // Handle deleted objects
            if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                Task {
                    await self.processDeletedObjects(deletedObjects, for: type)
                }
            }
            
            // Save new anchor
            if let newAnchor = newAnchor {
                self.saveAnchor(newAnchor, for: type)
                anchor = newAnchor
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            // Handle updates (same as initial handler)
        }
        
        healthStore.execute(query)
    }
    
    private func loadAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: "anchor_\(type.identifier)") else {
            return nil
        }
        
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKQueryAnchor.self,
            from: data
        )
    }
    
    private func saveAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        ) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: "anchor_\(type.identifier)")
    }
}
```

## Implementation Guide

### 1. Project Structure
```
HealthKit/
├── Manager/
│   ├── HealthKitManager.swift
│   ├── HealthDataSyncCoordinator.swift
│   └── WatchHealthManager.swift
├── Models/
│   ├── HealthKitTypes.swift
│   ├── VitalSigns.swift
│   ├── Activity.swift
│   ├── Sleep.swift
│   └── MentalWellbeing.swift
├── Queries/
│   ├── VitalSignsQueries.swift
│   ├── ActivityQueries.swift
│   ├── SleepQueries.swift
│   └── WorkoutQueries.swift
├── Sync/
│   ├── BackgroundSyncManager.swift
│   ├── DataUploader.swift
│   └── ConflictResolver.swift
└── Extensions/
    ├── HKQuantityType+Extensions.swift
    ├── HKUnit+Extensions.swift
    └── Date+HealthKit.swift
```

### 2. SwiftUI Integration
```swift
// MARK: - HealthKit Permission View
struct HealthKitPermissionView: View {
    @StateObject private var healthManager = HealthKitManager()
    @State private var isRequestingAuth = false
    @State private var authError: Error?
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Connect to Apple Health")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("CLARITY syncs with Apple Health to provide comprehensive health insights")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "applewatch",
                    title: "Apple Watch Integration",
                    description: "Automatic sync of health data from your Apple Watch"
                )
                
                FeatureRow(
                    icon: "waveform.path.ecg",
                    title: "Real-time Monitoring",
                    description: "Track vital signs and get instant health insights"
                )
                
                FeatureRow(
                    icon: "lock.fill",
                    title: "Private & Secure",
                    description: "Your health data is encrypted and never shared"
                )
            }
            
            Spacer()
            
            // Action Button
            CLARITYButton(
                title: "Enable Health Access",
                style: .primary,
                action: requestAuthorization,
                isLoading: isRequestingAuth
            )
            .padding(.horizontal)
            
            Button("Skip for now") {
                // Handle skip
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .alert("Authorization Failed", isPresented: .constant(authError != nil)) {
            Button("OK") {
                authError = nil
            }
        } message: {
            Text(authError?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func requestAuthorization() {
        isRequestingAuth = true
        
        Task {
            do {
                try await healthManager.requestAuthorization()
                // Navigate to next screen
            } catch {
                authError = error
            }
            
            isRequestingAuth = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
```

## Testing Strategy

### 1. Unit Tests
```swift
final class HealthKitManagerTests: XCTestCase {
    var sut: HealthKitManager!
    var mockHealthStore: MockHealthStore!
    
    override func setUp() {
        super.setUp()
        mockHealthStore = MockHealthStore()
        sut = HealthKitManager(healthStore: mockHealthStore)
    }
    
    func test_requestAuthorization_success() async throws {
        // Given
        mockHealthStore.authorizationResult = .success(())
        
        // When
        try await sut.requestAuthorization()
        
        // Then
        XCTAssertEqual(sut.authorizationStatus, .authorized)
        XCTAssertTrue(mockHealthStore.requestAuthorizationCalled)
    }
    
    func test_fetchHeartRate_returnsCorrectData() async throws {
        // Given
        let expectedSamples = createMockHeartRateSamples()
        mockHealthStore.queryResult = .success(expectedSamples)
        
        // When
        let readings = try await sut.fetchHeartRateData(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )
        
        // Then
        XCTAssertEqual(readings.count, expectedSamples.count)
        XCTAssertEqual(readings.first?.value, 72)
    }
}
```

### 2. Integration Tests
```swift
final class HealthKitIntegrationTests: XCTestCase {
    func test_realHealthKitAuthorization() async throws {
        // Only run on real device
        guard HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit not available on simulator")
        }
        
        let manager = HealthKitManager()
        
        // Request authorization
        try await manager.requestAuthorization()
        
        // Verify we can query data
        let readings = try await manager.fetchHeartRateData(
            from: Date().addingTimeInterval(-86400),
            to: Date()
        )
        
        XCTAssertNotNil(readings)
    }
}
```

## HIPAA Compliance

### 1. Data Handling Requirements
```swift
struct HIPAACompliantHealthDataHandler {
    // MARK: - Encryption
    private func encryptHealthData(_ data: Data) throws -> Data {
        // Use AES-256 encryption
        let key = try getOrCreateEncryptionKey()
        return try AES256.encrypt(data, key: key)
    }
    
    // MARK: - Audit Logging
    private func logDataAccess(
        userId: String,
        dataType: String,
        action: DataAction,
        timestamp: Date = Date()
    ) {
        let auditEntry = AuditLogEntry(
            userId: userId,
            dataType: dataType,
            action: action,
            timestamp: timestamp,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        )
        
        // Store in secure audit log
        AuditLogger.shared.log(auditEntry)
    }
    
    enum DataAction: String {
        case read = "READ"
        case write = "WRITE"
        case delete = "DELETE"
        case share = "SHARE"
    }
}

// MARK: - Secure Storage
extension HealthKitManager {
    private func securelyStoreHealthData(_ samples: [HKSample]) throws {
        // Never log PHI
        print("Storing \(samples.count) health samples") // OK
        // print("Heart rate: \(samples.first)") // NOT OK - contains PHI
        
        // Encrypt before storage
        let data = try JSONEncoder().encode(samples)
        let encrypted = try encryptHealthData(data)
        
        // Store in Keychain or encrypted database
        try KeychainManager.shared.store(encrypted, for: "health_data")
    }
}
```

### 2. User Consent Management
```swift
struct ConsentManager {
    static func recordConsent(for dataTypes: Set<HKSampleType>) {
        let consent = HealthDataConsent(
            id: UUID(),
            userId: currentUserId,
            consentedTypes: dataTypes.map { $0.identifier },
            consentDate: Date(),
            consentVersion: "2.0"
        )
        
        // Store consent record
        ConsentStorage.shared.store(consent)
        
        // Log consent event
        AuditLogger.shared.logConsentEvent(consent)
    }
    
    static func hasValidConsent(for type: HKSampleType) -> Bool {
        guard let consent = ConsentStorage.shared.getCurrentConsent() else {
            return false
        }
        
        return consent.consentedTypes.contains(type.identifier) &&
               !consent.isExpired
    }
}
```

## Best Practices

1. **Always check availability** before using HealthKit features
2. **Request minimal permissions** - only what your app needs
3. **Handle authorization changes** - users can revoke at any time
4. **Batch operations** for efficiency
5. **Use background delivery** sparingly to preserve battery
6. **Encrypt all health data** at rest and in transit
7. **Never log PHI** in production
8. **Provide clear value** to users for sharing their data
9. **Test on real devices** - simulator has limitations
10. **Follow Apple's guidelines** for health app review

## Troubleshooting

### Common Issues

1. **"HealthKit is not available"**
   - Not available on iPad or simulator (limited functionality)
   - Ensure HealthKit capability is enabled

2. **"Authorization request not showing"**
   - Check Info.plist descriptions
   - Verify entitlements

3. **"Background delivery not working"**
   - Enable Background Modes capability
   - Check background task registration

4. **"Data not syncing from Apple Watch"**
   - Ensure Watch app has proper entitlements
   - Check if data is being saved to HealthKit

## References

- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [WWDC 2024: What's new in HealthKit](https://developer.apple.com/videos/play/wwdc2024/10109/)
- [Human Interface Guidelines - HealthKit](https://developer.apple.com/design/human-interface-guidelines/healthkit)
- [App Store Review Guidelines - Health](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)