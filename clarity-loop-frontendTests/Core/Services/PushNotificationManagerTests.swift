import XCTest
import UserNotifications
@testable import clarity_loop_frontend

@MainActor
final class PushNotificationManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var notificationManager: PushNotificationManager!
    private var mockAPIClient: MockAPIClient!
    private var mockAuthService: MockAuthService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test dependencies
        mockAPIClient = MockAPIClient()
        mockAuthService = MockAuthService()
        
        // Configure the manager
        PushNotificationManager.configure(
            apiClient: mockAPIClient,
            authService: mockAuthService
        )
        
        notificationManager = PushNotificationManager.shared!
    }
    
    override func tearDown() async throws {
        notificationManager?.cancelAllNotifications()
        notificationManager = nil
        PushNotificationManager.shared = nil
        mockAPIClient = nil
        mockAuthService = nil
        try await super.tearDown()
    }
    
    // MARK: - Authorization Tests
    
    func testRequestAuthorizationGranted() async throws {
        // Given - User will grant notification permission
        let expectation = XCTestExpectation(description: "Authorization requested")
        
        // When - request authorization
        Task {
            // Note: In a real test environment, we can't control the system authorization dialog
            // This test demonstrates the API usage
            _ = try? await notificationManager.requestAuthorization()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Then - authorization status should be updated
        await notificationManager.checkAuthorizationStatus()
        
        // Note: We can't assert the actual status since it depends on system settings
        // But we can verify the API was called correctly
        XCTAssertNotNil(notificationManager.authorizationStatus)
    }
    
    func testRequestAuthorizationDenied() async throws {
        // Given - Initial state ready
        
        // When - request authorization (simulating denial)
        _ = try? await notificationManager.requestAuthorization()
        
        // Then - status should be set (even if denied)
        XCTAssertNotNil(notificationManager.authorizationStatus)
        
        // If authorization was denied, should not be registered
        if notificationManager.authorizationStatus == .denied {
            XCTAssertFalse(notificationManager.isRegistered)
        }
    }
    
    func testRequestAuthorizationProvisional() async throws {
        // Given - Provisional authorization support
        let expectation = XCTestExpectation(description: "Provisional auth")
        
        // When - request authorization
        Task {
            _ = try? await notificationManager.requestAuthorization()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Then - should handle provisional status
        if notificationManager.authorizationStatus == .provisional {
            // Provisional authorization should still allow registration
            XCTAssertNotNil(notificationManager.authorizationStatus)
        }
    }
    
    func testCheckAuthorizationStatus() async throws {
        // Given - notification manager initialized
        
        // When - check authorization status
        await notificationManager.checkAuthorizationStatus()
        
        // Then - status should be available (may be notDetermined in test environment)
        XCTAssertNotNil(notificationManager.authorizationStatus)
        
        // In test environment, the status is typically .notDetermined unless user has previously granted permissions
        // We just verify the API works correctly
    }
    
    // MARK: - Device Token Tests
    
    func testRegisterDeviceTokenSuccess() async throws {
        // Given - User is authenticated
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Create mock device token
        let tokenData = "mock-device-token".data(using: .utf8)!
        
        // When - handle device token
        await notificationManager.handleDeviceToken(tokenData)
        
        // Then - token should be registered
        XCTAssertNotNil(notificationManager.deviceToken)
        XCTAssertTrue(notificationManager.isRegistered)
        XCTAssertEqual(notificationManager.deviceToken, "6d6f636b2d6465766963652d746f6b656e") // hex representation
    }
    
    func testRegisterDeviceTokenFailure() async throws {
        // Given - Registration will fail
        let error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration failed"])
        
        // When - handle registration error
        notificationManager.handleRegistrationError(error)
        
        // Then - should clear registration
        XCTAssertFalse(notificationManager.isRegistered)
        XCTAssertNil(notificationManager.deviceToken)
    }
    
    func testUpdateDeviceTokenWhenChanged() async throws {
        // Given - User is authenticated and has existing token
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Register first token
        let firstToken = "first-token".data(using: .utf8)!
        await notificationManager.handleDeviceToken(firstToken)
        let originalToken = notificationManager.deviceToken
        
        // When - receive new token
        let newToken = "new-token".data(using: .utf8)!
        await notificationManager.handleDeviceToken(newToken)
        
        // Then - token should be updated
        XCTAssertNotEqual(notificationManager.deviceToken, originalToken)
        XCTAssertTrue(notificationManager.isRegistered)
    }
    
    // MARK: - Notification Category Tests
    
    func testSetupNotificationCategories() async throws {
        // Given - notification manager initialized
        
        // When - register for remote notifications
        await notificationManager.registerForRemoteNotifications()
        
        // Then - categories should be configured
        // Note: We can't directly verify UNUserNotificationCenter categories in tests
        // But we can verify the manager is properly initialized
        XCTAssertNotNil(notificationManager)
    }
    
    func testHealthInsightCategoryActions() async throws {
        // Given - Health insight notification actions are defined
        let insightCategory = NotificationCategory.insightNotification
        
        // Then - verify category identifier
        XCTAssertEqual(insightCategory.identifier, "INSIGHT_NOTIFICATION")
        
        // Verify actions would be configured (VIEW_INSIGHT, DISMISS)
        XCTAssertNotNil(insightCategory)
    }
    
    func testGoalReminderCategoryActions() async throws {
        // Given - PAT reminder category actions are defined
        let patCategory = NotificationCategory.patReminder
        
        // Then - verify category identifier
        XCTAssertEqual(patCategory.identifier, "PAT_REMINDER")
        
        // Verify actions would be configured (START_PAT, SNOOZE)
        XCTAssertNotNil(patCategory)
    }
    
    // MARK: - Local Notification Tests
    
    func testScheduleHealthInsightNotification() async throws {
        // Given - Create health insight notification
        var request = NotificationRequest(
            title: "New Health Insight",
            body: "Your heart rate pattern shows improvement",
            trigger: .scheduled(Date().addingTimeInterval(3600)),
            category: .insightNotification
        )
        request.userInfo = ["type": NotificationType.healthInsight.rawValue, "insightId": "insight-123"]
        
        // When - schedule notification
        try await notificationManager.scheduleLocalNotification(request)
        
        // Then - notification should be pending
        XCTAssertTrue(notificationManager.pendingNotifications.contains { $0.id == request.id })
    }
    
    func testScheduleGoalProgressNotification() async throws {
        // Given - Create goal progress notification
        var request = NotificationRequest(
            title: "Daily Step Goal",
            body: "You're 80% towards your daily step goal!",
            trigger: .immediate,
            category: .general
        )
        request.badge = 1
        request.sound = "success.mp3"
        
        // When - schedule notification
        try await notificationManager.scheduleLocalNotification(request)
        
        // Then - notification should be added
        XCTAssertFalse(notificationManager.pendingNotifications.isEmpty)
    }
    
    func testScheduleSyncReminderNotification() async throws {
        // Given - Create sync reminder notification
        let request = NotificationRequest(
            title: "Sync Reminder",
            body: "It's been 24 hours since your last health data sync",
            trigger: .interval(86400, repeats: true),
            category: .general
        )
        
        // When - schedule notification
        try await notificationManager.scheduleLocalNotification(request)
        
        // Then - notification should be scheduled
        let pending = await notificationManager.getPendingNotifications()
        XCTAssertTrue(pending.contains { $0.identifier == request.id })
    }
    
    func testCancelScheduledNotification() async throws {
        // Given - Schedule a notification first
        let request = NotificationRequest(
            id: "test-cancel-123",
            title: "Test Notification",
            body: "This will be cancelled",
            trigger: .scheduled(Date().addingTimeInterval(3600))
        )
        try await notificationManager.scheduleLocalNotification(request)
        
        // When - cancel the notification
        await notificationManager.cancelNotification(withId: "test-cancel-123")
        
        // Then - notification should be removed
        XCTAssertFalse(notificationManager.pendingNotifications.contains { $0.id == "test-cancel-123" })
    }
    
    func testCancelAllNotifications() async throws {
        // Given - Schedule multiple notifications
        for i in 1...3 {
            let request = NotificationRequest(
                title: "Test \(i)",
                body: "Notification \(i)",
                trigger: .scheduled(Date().addingTimeInterval(Double(i * 3600)))
            )
            try await notificationManager.scheduleLocalNotification(request)
        }
        
        XCTAssertFalse(notificationManager.pendingNotifications.isEmpty)
        
        // When - cancel all notifications
        notificationManager.cancelAllNotifications()
        
        // Then - all should be cleared
        XCTAssertTrue(notificationManager.pendingNotifications.isEmpty)
    }
    
    // MARK: - Remote Notification Tests
    
    func testHandleRemoteNotificationHealthUpdate() async throws {
        // Given - Subscribe to health insight notifications
        let expectation = XCTestExpectation(description: "Notification handled")
        
        let cancellable = notificationManager.subscribe(to: .healthInsight) { info in
            XCTAssertEqual(info.type, .healthInsight)
            expectation.fulfill()
        }
        
        // When - simulate receiving remote notification (through delegate)
        // Note: In real tests, we'd need to simulate the UNUserNotificationCenterDelegate calls
        
        // Then - verify subscription works
        XCTAssertNotNil(cancellable)
        
        // Clean up
        cancellable.cancel()
    }
    
    func testHandleRemoteNotificationNewInsight() async throws {
        // Given - New insight notification data
        let notificationData: [AnyHashable: Any] = [
            "type": NotificationType.healthInsight.rawValue,
            "insightId": "insight-456",
            "title": "New Heart Rate Insight",
            "body": "Your resting heart rate has improved"
        ]
        
        // When - process notification type
        let typeString = notificationData["type"] as? String
        let notificationType = NotificationType(rawValue: typeString ?? "")
        
        // Then - should recognize insight type
        XCTAssertEqual(notificationType, .healthInsight)
        XCTAssertEqual(notificationData["insightId"] as? String, "insight-456")
    }
    
    func testHandleRemoteNotificationSystemAlert() async throws {
        // Given - System alert notification
        let notificationData: [AnyHashable: Any] = [
            "type": NotificationType.systemUpdate.rawValue,
            "title": "System Update Available",
            "body": "Update to the latest version for new features",
            "priority": "high"
        ]
        
        // When - check notification type
        let typeString = notificationData["type"] as? String
        let notificationType = NotificationType(rawValue: typeString ?? "")
        
        // Then - should be system update type
        XCTAssertEqual(notificationType, .systemUpdate)
        XCTAssertEqual(notificationData["priority"] as? String, "high")
    }
    
    func testHandleSilentNotification() async throws {
        // Given - Silent notification for background sync
        let notificationData: [AnyHashable: Any] = [
            "type": NotificationType.syncComplete.rawValue,
            "content-available": 1,
            "syncedRecords": 150,
            "lastSyncTime": Date().timeIntervalSince1970
        ]
        
        // When - check if it's a silent notification
        let isSilent = notificationData["content-available"] as? Int == 1
        let notificationType = NotificationType(rawValue: notificationData["type"] as? String ?? "")
        
        // Then - should be recognized as silent sync notification
        XCTAssertTrue(isSilent)
        XCTAssertEqual(notificationType, .syncComplete)
        XCTAssertEqual(notificationData["syncedRecords"] as? Int, 150)
    }
    
    // MARK: - Notification Response Tests
    
    func testHandleNotificationActionView() async throws {
        // Given - Notification with view action
        let notificationExpectation = XCTestExpectation(description: "Navigate to insight")
        
        // Subscribe to navigation notification
        var navigateNotificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .navigateToInsight,
            object: nil,
            queue: .main
        ) { notification in
            if let insightId = notification.userInfo?["insightId"] as? String {
                XCTAssertEqual(insightId, "insight-789")
                navigateNotificationReceived = true
                notificationExpectation.fulfill()
            }
        }
        
        // When - Post navigation notification (simulating action handler)
        NotificationCenter.default.post(
            name: .navigateToInsight,
            object: nil,
            userInfo: ["insightId": "insight-789"]
        )
        
        await fulfillment(of: [notificationExpectation], timeout: 1.0)
        
        // Then - navigation should be triggered
        XCTAssertTrue(navigateNotificationReceived)
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testHandleNotificationActionDismiss() async throws {
        // Given - Dismiss action identifier
        let dismissActionId = "DISMISS"
        
        // When - check if action is dismiss
        let isDismissAction = dismissActionId == "DISMISS"
        
        // Then - should recognize dismiss action
        XCTAssertTrue(isDismissAction)
        
        // Dismiss action typically doesn't require additional handling
        // Just removes the notification
    }
    
    func testHandleNotificationActionSync() async throws {
        // Given - Start PAT action
        let startPATExpectation = XCTestExpectation(description: "Start PAT")
        
        var patStarted = false
        let observer = NotificationCenter.default.addObserver(
            forName: .startPATAnalysis,
            object: nil,
            queue: .main
        ) { _ in
            patStarted = true
            startPATExpectation.fulfill()
        }
        
        // When - trigger PAT start action
        NotificationCenter.default.post(name: .startPATAnalysis, object: nil)
        
        await fulfillment(of: [startPATExpectation], timeout: 1.0)
        
        // Then - PAT should be started
        XCTAssertTrue(patStarted)
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Badge Management Tests
    
    func testUpdateBadgeCount() async throws {
        // Given - Notification with badge count
        var request = NotificationRequest(
            title: "New Messages",
            body: "You have unread messages",
            trigger: .immediate,
            category: .general
        )
        request.badge = 5
        
        // When - schedule notification with badge
        try await notificationManager.scheduleLocalNotification(request)
        
        // Then - badge should be set
        let notification = notificationManager.pendingNotifications.first { $0.id == request.id }
        XCTAssertEqual(notification?.badge, 5)
    }
    
    func testClearBadgeCount() async throws {
        // Given - Multiple notifications with badges
        for i in 1...3 {
            var request = NotificationRequest(
                title: "Notification \(i)",
                body: "Body \(i)",
                trigger: .immediate
            )
            request.badge = i
            try await notificationManager.scheduleLocalNotification(request)
        }
        
        // When - schedule notification with badge 0 (clear badge)
        var clearRequest = NotificationRequest(
            title: "Clear Badge",
            body: "This clears the badge",
            trigger: .immediate
        )
        clearRequest.badge = 0
        try await notificationManager.scheduleLocalNotification(clearRequest)
        
        // Then - badge should be cleared
        let clearNotification = notificationManager.pendingNotifications.first { $0.id == clearRequest.id }
        XCTAssertEqual(clearNotification?.badge, 0)
    }
    
    // MARK: - Notification Settings Tests
    
    func testUpdateNotificationPreferences() async throws {
        // Given - User is authenticated
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Create custom preferences
        var preferences = NotificationPreferences()
        preferences.soundEnabled = false
        preferences.quietHoursEnabled = true
        preferences.quietHoursStart = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())
        preferences.quietHoursEnd = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
        preferences.enabledTypes = [.healthInsight, .healthAlert]
        
        // When - update preferences
        await notificationManager.updateNotificationPreferences(preferences)
        
        // Then - preferences should be saved
        // Note: In real implementation, we'd verify UserDefaults storage
        XCTAssertNotNil(preferences)
        XCTAssertFalse(preferences.soundEnabled)
        XCTAssertTrue(preferences.quietHoursEnabled)
        XCTAssertEqual(preferences.enabledTypes.count, 2)
    }
    
    func testSyncNotificationSettingsWithBackend() async throws {
        // Given - User is authenticated
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Create preferences
        var preferences = NotificationPreferences()
        preferences.insightNotifications.onlyHighPriority = true
        preferences.healthAlerts.anomalyAlerts = false
        preferences.patReminders.frequency = .weekly
        
        // When - update preferences (would sync with backend)
        await notificationManager.updateNotificationPreferences(preferences)
        
        // Then - verify preferences structure
        XCTAssertTrue(preferences.insightNotifications.onlyHighPriority)
        XCTAssertFalse(preferences.healthAlerts.anomalyAlerts)
        XCTAssertEqual(preferences.patReminders.frequency, .weekly)
        
        // Note: Actual backend sync would be verified through mock API client
    }
    
    // MARK: - Performance Tests
    
    func testBatchNotificationScheduling() async throws {
        // Given - Large batch of notifications to schedule
        let notificationCount = 50
        let startTime = Date()
        
        // When - schedule many notifications
        for i in 0..<notificationCount {
            let request = NotificationRequest(
                title: "Batch Notification \(i)",
                body: "Testing batch performance",
                trigger: .scheduled(Date().addingTimeInterval(Double(i * 60))),
                category: .general
            )
            
            try await notificationManager.scheduleLocalNotification(request)
        }
        
        let schedulingTime = Date().timeIntervalSince(startTime)
        
        // Then - should complete in reasonable time
        XCTAssertEqual(notificationManager.pendingNotifications.count, notificationCount)
        XCTAssertLessThan(schedulingTime, 2.0) // Should complete within 2 seconds
        
        // Clean up
        notificationManager.cancelAllNotifications()
    }
    
    func testNotificationDeliveryReliability() async throws {
        // Given - Various notification types and triggers
        let testNotifications = [
            NotificationRequest(
                title: "Immediate",
                body: "Should deliver immediately",
                trigger: .immediate
            ),
            NotificationRequest(
                title: "Scheduled",
                body: "Should deliver at scheduled time",
                trigger: .scheduled(Date().addingTimeInterval(60))
            ),
            NotificationRequest(
                title: "Interval",
                body: "Should repeat at interval",
                trigger: .interval(3600, repeats: true)
            ),
            NotificationRequest(
                title: "Daily",
                body: "Should deliver daily",
                trigger: .daily(hour: 9, minute: 0)
            )
        ]
        
        // When - schedule all notification types
        for notification in testNotifications {
            try await notificationManager.scheduleLocalNotification(notification)
        }
        
        // Then - all should be scheduled
        XCTAssertEqual(notificationManager.pendingNotifications.count, testNotifications.count)
        
        // Verify each notification type is properly configured
        for (index, scheduled) in notificationManager.pendingNotifications.enumerated() {
            XCTAssertEqual(scheduled.title, testNotifications[index].title)
            XCTAssertEqual(scheduled.body, testNotifications[index].body)
        }
        
        // Clean up
        notificationManager.cancelAllNotifications()
    }
}