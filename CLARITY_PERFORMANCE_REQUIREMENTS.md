# CLARITY Performance Requirements & Optimization Guide

## Overview

This document defines specific performance requirements and optimization strategies for the CLARITY Pulse app. All metrics are measurable and must be verified before release.

## Performance Requirements

### App Launch Time

| Metric | Target | Maximum | Measurement |
|--------|--------|---------|-------------|
| Cold Launch | < 1.0s | 2.0s | Time to first meaningful paint |
| Warm Launch | < 0.5s | 1.0s | Time from tap to usable UI |
| Background to Foreground | < 0.3s | 0.5s | Time to responsive UI |

### Memory Usage

| Metric | Target | Maximum | Condition |
|--------|--------|---------|-----------|
| Idle Memory | < 50MB | 100MB | App in foreground, no activity |
| Active Memory | < 150MB | 250MB | During data sync |
| Peak Memory | < 300MB | 500MB | During PAT analysis |
| Background Memory | < 30MB | 50MB | Background sync |

### UI Responsiveness

| Metric | Target | Maximum | Description |
|--------|--------|---------|-------------|
| Main Thread Block | 0ms | 16ms | Per frame (60 FPS) |
| Touch Response | < 50ms | 100ms | Time to visual feedback |
| List Scrolling | 60 FPS | 30 FPS | Smooth scrolling |
| Animation FPS | 60 FPS | 30 FPS | All animations |

### Network Performance

| Operation | Target | Maximum | Size |
|-----------|--------|---------|------|
| Auth Request | < 500ms | 2s | ~1KB |
| Health Data Upload | < 2s | 5s | ~100KB |
| Insight Generation | < 3s | 10s | Variable |
| Image Load | < 1s | 3s | ~500KB |
| Sync Operation | < 5s | 30s | ~1MB |

### Battery Usage

| Scenario | Target | Maximum | Duration |
|----------|--------|---------|----------|
| Active Use | < 10%/hr | 15%/hr | Continuous |
| Background Sync | < 2%/hr | 5%/hr | Periodic |
| Idle | < 1%/hr | 2%/hr | App suspended |

## Implementation Strategies

### 1. App Launch Optimization

```swift
// AppDelegate or App struct
@main
struct ClarityApp: App {
    init() {
        // ⚠️ HUMAN INTERVENTION: Profile app launch in Instruments
        
        // Defer non-critical initialization
        Task(priority: .background) {
            await initializeNonCriticalServices()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Use lazy loading for initial view
            LazyView {
                ContentView()
            }
        }
    }
    
    private func initializeNonCriticalServices() async {
        // Initialize analytics
        await AnalyticsService.shared.initialize()
        
        // Preload frequently used data
        await CacheManager.shared.preloadCommonData()
        
        // Register background tasks
        BackgroundTaskManager.shared.register()
    }
}

// Lazy loading wrapper
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    @State private var cache: Content?
    
    var body: some View {
        Group {
            if let content = cache {
                content
            } else {
                ProgressView()
                    .onAppear {
                        cache = build()
                    }
            }
        }
    }
}
```

### 2. Memory Management

```swift
// Image caching with memory limits
final class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "image.cache.io", qos: .background)
    
    init() {
        // Set memory limits
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        // Check memory cache
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // Check disk cache
        if let diskCached = await loadFromDisk(url: url) {
            cache.setObject(diskCached, forKey: key, cost: diskCached.jpegData(compressionQuality: 1)?.count ?? 0)
            return diskCached
        }
        
        // Download
        return await downloadImage(from: url)
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
    }
}

// SwiftData batch operations
extension ModelContext {
    func batchInsert<T: PersistentModel>(_ models: [T], batchSize: Int = 100) throws {
        for batch in models.chunked(into: batchSize) {
            for model in batch {
                insert(model)
            }
            
            // Save after each batch to control memory
            try save()
            
            // Allow autorelease pool to drain
            autoreleasepool { }
        }
    }
}
```

### 3. UI Performance

```swift
// Optimized list view
struct OptimizedHealthDataList: View {
    @Query(sort: \HealthMetric.timestamp, order: .reverse) 
    private var metrics: [HealthMetric]
    
    // Virtualized list with fixed row heights
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(metrics) { metric in
                    HealthMetricRow(metric: metric)
                        .frame(height: 80) // Fixed height for performance
                        .id(metric.id)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// Optimized row with async image loading
struct HealthMetricRow: View {
    let metric: HealthMetric
    
    var body: some View {
        HStack(spacing: 16) {
            // Use SF Symbols instead of custom images when possible
            Image(systemName: metric.type.symbolName)
                .font(.title2)
                .foregroundColor(metric.type.color)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.type.displayName)
                    .font(.headline)
                
                Text(metric.formattedValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(metric.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// Debounced search
struct SearchableHealthData: View {
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    
    var body: some View {
        NavigationStack {
            FilteredHealthDataList(searchTerm: debouncedSearchText)
                .searchable(text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    // Debounce search
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                        if newValue == searchText {
                            debouncedSearchText = newValue
                        }
                    }
                }
        }
    }
}
```

### 4. Network Optimization

```swift
// Request coalescing
actor RequestCoalescer {
    private var pendingRequests: [String: Task<Data, Error>] = [:]
    
    func request(endpoint: Endpoint) async throws -> Data {
        let key = endpoint.cacheKey
        
        // Check if request is already in flight
        if let pending = pendingRequests[key] {
            return try await pending.value
        }
        
        // Create new request
        let task = Task<Data, Error> {
            defer { pendingRequests[key] = nil }
            return try await performRequest(endpoint)
        }
        
        pendingRequests[key] = task
        return try await task.value
    }
}

// Adaptive quality based on network
final class AdaptiveNetworkClient {
    private let reachability = NetworkReachability()
    
    func uploadHealthData(_ data: HealthDataUploadRequest) async throws {
        let quality = reachability.connectionQuality
        
        switch quality {
        case .high:
            // Full resolution, all data
            try await uploadFullData(data)
            
        case .medium:
            // Compressed, batched
            let compressed = try compress(data, level: .medium)
            try await uploadBatched(compressed, batchSize: 50)
            
        case .low:
            // Minimal data, maximum compression
            let minimal = data.minimalVersion()
            let compressed = try compress(minimal, level: .maximum)
            try await uploadBatched(compressed, batchSize: 10)
            
        case .none:
            // Queue for later
            try await OfflineQueue.shared.enqueue(data)
        }
    }
}

// HTTP/2 multiplexing with priority
extension URLRequest {
    mutating func setPriority(_ priority: RequestPriority) {
        switch priority {
        case .critical:
            setValue("urgent", forHTTPHeaderField: "Priority")
        case .high:
            setValue("high", forHTTPHeaderField: "Priority")
        case .normal:
            setValue("normal", forHTTPHeaderField: "Priority")
        case .low:
            setValue("low", forHTTPHeaderField: "Priority")
        }
    }
}
```

### 5. Background Performance

```swift
// Efficient background sync
final class BackgroundSyncManager {
    func performBackgroundSync() async throws {
        // Use background URLSession
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.clarity.sync"
        )
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        let session = URLSession(configuration: config)
        
        // Batch operations
        let unsyncedData = try await fetchUnsyncedData(limit: 100)
        
        // Create upload task
        let uploadData = try JSONEncoder().encode(unsyncedData)
        let request = try createUploadRequest()
        
        let task = session.uploadTask(with: request, from: uploadData)
        task.earliestBeginDate = Date().addingTimeInterval(60) // Delay 1 minute
        task.countOfBytesClientExpectsToSend = Int64(uploadData.count)
        task.countOfBytesClientExpectsToReceive = 1024 // Small response
        
        task.resume()
    }
}

// Background processing with battery awareness
final class BatteryAwareProcessor {
    func shouldProcessNow() -> Bool {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let batteryLevel = device.batteryLevel
        let batteryState = device.batteryState
        
        switch batteryState {
        case .charging, .full:
            return true
        case .unplugged:
            return batteryLevel > 0.2 // Only if > 20% battery
        case .unknown:
            return false
        @unknown default:
            return false
        }
    }
}
```

### 6. SwiftData Performance

```swift
// Optimized queries
extension ModelContext {
    func fetchHealthMetrics(
        dateRange: ClosedRange<Date>,
        limit: Int = 100
    ) throws -> [HealthMetric] {
        var descriptor = FetchDescriptor<HealthMetric>(
            predicate: #Predicate { metric in
                metric.timestamp >= dateRange.lowerBound &&
                metric.timestamp <= dateRange.upperBound
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = false
        descriptor.propertiesToFetch = [\.id, \.type, \.value, \.timestamp]
        
        return try fetch(descriptor)
    }
}

// Batch delete optimization
extension ModelContext {
    func batchDelete<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>
    ) throws {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        let objects = try fetch(descriptor)
        
        // Delete in batches
        for batch in objects.chunked(into: 100) {
            for object in batch {
                delete(object)
            }
            try save()
        }
    }
}
```

## Performance Monitoring

### 1. MetricKit Integration

```swift
import MetricKit

final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()
    
    override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            processMetrics(payload)
        }
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            processDiagnostics(payload)
        }
    }
    
    private func processMetrics(_ payload: MXMetricPayload) {
        // App launch metrics
        if let launchMetrics = payload.applicationLaunchMetrics {
            Logger.performance.info("""
                Launch Time:
                - First Draw: \(launchMetrics.histogrammedTimeToFirstDraw)
                - Resume Time: \(launchMetrics.histogrammedApplicationResumeTime)
            """)
        }
        
        // Memory metrics
        if let memoryMetrics = payload.memoryMetrics {
            Logger.performance.info("""
                Memory:
                - Peak: \(memoryMetrics.peakMemoryUsage)
                - Average: \(memoryMetrics.averageSuspendedMemory)
            """)
        }
    }
}
```

### 2. Custom Performance Tracking

```swift
final class PerformanceTracker {
    static let shared = PerformanceTracker()
    
    private var activeTimers: [String: CFAbsoluteTime] = [:]
    
    func startTimer(_ identifier: String) {
        activeTimers[identifier] = CFAbsoluteTimeGetCurrent()
    }
    
    func endTimer(_ identifier: String) -> TimeInterval? {
        guard let startTime = activeTimers.removeValue(forKey: identifier) else {
            return nil
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log if exceeds threshold
        let thresholds: [String: TimeInterval] = [
            "app.launch": 2.0,
            "data.sync": 5.0,
            "view.load": 0.5,
            "api.request": 3.0
        ]
        
        if let threshold = thresholds[identifier], duration > threshold {
            Logger.performance.warning("\(identifier) took \(duration)s (threshold: \(threshold)s)")
        }
        
        return duration
    }
}

// Usage
PerformanceTracker.shared.startTimer("view.load.dashboard")
// ... loading
PerformanceTracker.shared.endTimer("view.load.dashboard")
```

## Testing Performance

### 1. Unit Tests for Performance

```swift
final class PerformanceTests: XCTestCase {
    func testLargeDataSetPerformance() throws {
        let context = DataController.test.viewContext
        
        // Create test data
        let metrics = (0..<10000).map { i in
            HealthMetric(
                type: .heartRate,
                value: Double.random(in: 60...100),
                unit: "bpm",
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                source: "Test"
            )
        }
        
        measure {
            // Insert
            for metric in metrics {
                context.insert(metric)
            }
            try? context.save()
            
            // Query
            let descriptor = FetchDescriptor<HealthMetric>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            _ = try? context.fetch(descriptor)
            
            // Clean up
            try? context.delete(model: HealthMetric.self)
        }
    }
}
```

### 2. UI Tests for Scrolling Performance

```swift
final class ScrollingPerformanceTests: XCTestCase {
    func testListScrollingPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to health data
        app.tabBars.buttons["Health"].tap()
        
        // Measure scrolling
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let table = app.tables.firstMatch
            table.swipeUp(velocity: .fast)
            table.swipeDown(velocity: .fast)
        }
    }
}
```

## Optimization Checklist

### Before Every Release

- [ ] Profile app launch time in Instruments
- [ ] Check memory usage during typical usage
- [ ] Verify 60 FPS scrolling on older devices
- [ ] Test with Network Link Conditioner (poor connection)
- [ ] Measure battery usage over 1 hour
- [ ] Review MetricKit reports
- [ ] Test on minimum supported device (iPhone 12)
- [ ] Verify background task efficiency
- [ ] Check for memory leaks
- [ ] Profile Core Data/SwiftData queries

### ⚠️ HUMAN INTERVENTION REQUIRED

1. **Instruments Profiling**: Must be done in Xcode
2. **Network Link Conditioner**: Requires device/simulator setup
3. **Battery Testing**: Requires real device testing
4. **Memory Leak Detection**: Use Xcode memory graph debugger
5. **FPS Measurement**: Use Xcode FPS gauge during testing

## Performance Budget

### Maximum Acceptable Values

```swift
struct PerformanceBudget {
    static let maxLaunchTime: TimeInterval = 2.0
    static let maxMemoryUsage: Int = 500_000_000 // 500MB
    static let minFPS: Int = 30
    static let maxNetworkTimeout: TimeInterval = 30.0
    static let maxBatteryUsagePerHour: Float = 0.15 // 15%
    static let maxBackgroundTime: TimeInterval = 30.0
    static let maxDatabaseQueryTime: TimeInterval = 0.5
}
```

---

Remember: Performance is a feature. Every millisecond counts!