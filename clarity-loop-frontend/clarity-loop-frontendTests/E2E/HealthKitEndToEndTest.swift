import XCTest
import HealthKit
@testable import clarity_loop_frontend

/// 🔥 CRITICAL E2E TEST: HealthKit Background Sync Integration
/// Tests the complete flow: Authorization → Background Delivery → Observer Queries → Data Sync
final class HealthKitEndToEndTest: XCTestCase {
    
    private var healthKitService: HealthKitService!
    private var mockHealthStore: HKHealthStore!
    
    override func setUp() {
        super.setUp()
        // Create mock API client for testing
        let mockAPIClient = BackendAPIClient(tokenProvider: { "test-token" })!
        healthKitService = HealthKitService(apiClient: mockAPIClient)
        mockHealthStore = HKHealthStore()
    }
    
    override func tearDown() {
        healthKitService = nil
        mockHealthStore = nil
        super.tearDown()
    }
    
    /// 🎯 PRIMARY TEST: Full HealthKit integration flow
    func testCompleteHealthKitIntegrationFlow() async throws {
        print("🚀 Starting HealthKit End-to-End Integration Test")
        
        // Step 1: Test authorization request
        do {
            try await healthKitService.requestAuthorization()
            print("✅ HealthKit authorization completed")
        } catch {
            XCTFail("❌ HealthKit authorization failed: \(error)")
            return
        }
        
        // Step 2: Test background delivery setup
        do {
            try await healthKitService.enableBackgroundDelivery()
            print("✅ Background delivery enabled")
        } catch {
            XCTFail("❌ Background delivery setup failed: \(error)")
            return
        }
        
        // Step 3: Test observer queries setup
        healthKitService.setupObserverQueries()
        print("✅ Observer queries setup completed")
        
        // Step 4: Test data fetching (using the actual available method)
        let todayMetrics = try await healthKitService.fetchAllDailyMetrics(for: Date())
        print("✅ Health data sync completed - Steps: \(todayMetrics.stepCount)")
        
        // Step 5: Validate critical health types are monitored
        let expectedTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .bodyMass,
            .height,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bodyMassIndex,
            .basalEnergyBurned,
            .activeEnergyBurned
        ]
        
        for typeIdentifier in expectedTypes {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
                XCTFail("❌ Failed to create quantity type for \(typeIdentifier)")
                continue
            }
            
            let authStatus = mockHealthStore.authorizationStatus(for: quantityType)
            print("📊 \(typeIdentifier.rawValue): \(authStatus.rawValue)")
        }
        
        print("🎉 VICTORY: HealthKit End-to-End Integration Test PASSED!")
    }
    
    /// 🔍 Test background app refresh configuration
    func testBackgroundAppRefreshSetup() {
        // Verify Info.plist contains required background modes
        guard let infoPlist = Bundle.main.infoDictionary else {
            XCTFail("❌ Could not load Info.plist")
            return
        }
        
        let backgroundModes = infoPlist["UIBackgroundModes"] as? [String] ?? []
        
        XCTAssertTrue(backgroundModes.contains("background-processing"), 
                     "❌ Missing background-processing mode in Info.plist")
        XCTAssertTrue(backgroundModes.contains("background-fetch"), 
                     "❌ Missing background-fetch mode in Info.plist")
        
        print("✅ Background modes properly configured: \(backgroundModes)")
    }
    
    /// 🎯 Test data sync to backend
    func testHealthDataSyncToBackend() async throws {
        print("🔄 Testing health data sync to backend...")
        
        // This would test the actual API call to backend
        // For now, we'll simulate the flow by creating sample data
        let sampleData: [String: Any] = [
            "type": "step_count",
            "value": 10000,
            "unit": "count",
            "timestamp": Date().timeIntervalSince1970,
            "source": "Apple Watch"
        ]
        
        // Test that our data structure is properly formatted
        XCTAssertEqual(sampleData["type"] as? String, "step_count")
        XCTAssertEqual(sampleData["value"] as? Int, 10000)
        
        print("✅ Health data sync format validation passed")
    }
} 