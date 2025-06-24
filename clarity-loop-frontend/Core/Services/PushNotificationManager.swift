import Combine
import Foundation
import UIKit
import UserNotifications

/// Manages push notifications for the app
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    // MARK: - Properties

    static var shared: PushNotificationManager?

    static func configure(apiClient: APIClientProtocol, authService: AuthServiceProtocol) {
        shared = PushNotificationManager(apiClient: apiClient, authService: authService)
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegistered = false
    @Published private(set) var deviceToken: String?
    @Published private(set) var pendingNotifications: [NotificationRequest] = []

    private let notificationCenter = UNUserNotificationCenter.current()
    private let apiClient: APIClientProtocol
    private let authService: AuthServiceProtocol

    private var cancellables = Set<AnyCancellable>()
    private var notificationHandlers: [NotificationType: [NotificationHandlerWrapper]] = [:]

    // MARK: - Configuration

    private let notificationCategories: Set<UNNotificationCategory> = {
        // Insight notification actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_INSIGHT",
            title: "View Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let insightCategory = UNNotificationCategory(
            identifier: "INSIGHT_NOTIFICATION",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Health alert actions
        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE",
            title: "Got it",
            options: []
        )

        let moreInfoAction = UNNotificationAction(
            identifier: "MORE_INFO",
            title: "Learn More",
            options: [.foreground]
        )

        let healthCategory = UNNotificationCategory(
            identifier: "HEALTH_ALERT",
            actions: [acknowledgeAction, moreInfoAction],
            intentIdentifiers: [],
            options: []
        )

        // PAT reminder actions
        let startAction = UNNotificationAction(
            identifier: "START_PAT",
            title: "Start Now",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind in 1 hour",
            options: []
        )

        let patCategory = UNNotificationCategory(
            identifier: "PAT_REMINDER",
            actions: [startAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        return [insightCategory, healthCategory, patCategory]
    }()

    // MARK: - Initialization

    init(apiClient: APIClientProtocol, authService: AuthServiceProtocol) {
        self.apiClient = apiClient
        self.authService = authService
        super.init()

        notificationCenter.delegate = self
        setupNotificationObservers()
    }

    // MARK: - Public Methods

    /// Request notification authorization
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]

        let granted = try await notificationCenter.requestAuthorization(options: options)
        await updateAuthorizationStatus()

        if granted {
            await registerForRemoteNotifications()
        }

        return granted
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        await updateAuthorizationStatus()
    }

    /// Register device for remote notifications
    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // Set notification categories
        notificationCenter.setNotificationCategories(notificationCategories)
    }

    /// Handle device token registration
    func handleDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        isRegistered = true

        // Register token with backend
        await registerTokenWithBackend(token)
    }

    /// Handle registration failure
    func handleRegistrationError(_ error: Error) {
        isRegistered = false
        deviceToken = nil
        print("Failed to register for remote notifications: \(error)")
    }

    /// Schedule a local notification
    func scheduleLocalNotification(_ request: NotificationRequest) async throws {
        let content = createNotificationContent(from: request)
        let trigger = createTrigger(from: request)

        let notificationRequest = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(notificationRequest)
        pendingNotifications.append(request)
    }

    /// Cancel a scheduled notification
    func cancelNotification(withId id: String) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        pendingNotifications.removeAll { $0.id == id }
    }

    /// Cancel all notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        pendingNotifications.removeAll()
    }

    /// Get pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }

    /// Subscribe to notification type
    func subscribe(to type: NotificationType, handler: @escaping NotificationHandler) -> AnyCancellable {
        if notificationHandlers[type] == nil {
            notificationHandlers[type] = []
        }

        let id = UUID()
        let wrapper = NotificationHandlerWrapper(id: id, handler: handler)
        notificationHandlers[type]?.append(wrapper)

        return AnyCancellable { [weak self] in
            self?.notificationHandlers[type]?.removeAll { $0.id == id }
        }
    }

    /// Configure notification preferences
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async {
        await savePreferences(preferences)

        // Update backend
        if let userId = await authService.currentUser?.id {
            try? await updateBackendPreferences(userId: userId, preferences: preferences)
        }
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Observe app becoming active to check authorization
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAuthorizationStatus()
                }
            }
            .store(in: &cancellables)

        // Observe auth state changes
        NotificationCenter.default.publisher(for: .authStateChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAuthStateChange()
                }
            }
            .store(in: &cancellables)
    }

    private func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func registerTokenWithBackend(_ token: String) async {
        guard let userId = await authService.currentUser?.id else { return }

        do {
            let _ = DeviceTokenRegistrationRequest(
                userId: userId,
                token: token,
                platform: "iOS",
                deviceInfo: getDeviceInfo()
            )

            // TODO: Implement when backend endpoint is available
            // try await apiClient.registerDeviceToken(request)
        }
    }

    private func updateBackendPreferences(userId: String, preferences: NotificationPreferences) async throws {
        let _ = NotificationPreferencesRequest(
            userId: userId,
            preferences: preferences
        )

        // TODO: Implement when backend endpoint is available
        // try await apiClient.updateNotificationPreferences(request)
    }

    private func createNotificationContent(from request: NotificationRequest) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        content.title = request.title
        content.body = request.body

        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }

        if let badge = request.badge {
            content.badge = NSNumber(value: badge)
        }

        if let sound = request.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = .default
        }

        content.categoryIdentifier = request.category.identifier
        content.userInfo = request.userInfo

        // Add attachments if any
        if let attachments = request.attachments {
            content.attachments = attachments.compactMap { createAttachment(from: $0) }
        }

        return content
    }

    private func createTrigger(from request: NotificationRequest) -> UNNotificationTrigger? {
        switch request.trigger {
        case .immediate:
            return nil

        case let .scheduled(date):
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case let .interval(interval, repeats):
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: repeats)

        case let .daily(hour, minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }

    private func createAttachment(from attachment: NotificationAttachment) -> UNNotificationAttachment? {
        do {
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(attachment.identifier)
                .appendingPathExtension(attachment.type.fileExtension)

            try attachment.data.write(to: fileURL)

            return try UNNotificationAttachment(
                identifier: attachment.identifier,
                url: fileURL,
                options: attachment.options
            )
        } catch {
            print("Failed to create attachment: \(error)")
            return nil
        }
    }

    private func handleAuthStateChange() async {
        if await authService.currentUser != nil {
            // Re-register device token if needed
            if deviceToken != nil {
                await registerForRemoteNotifications()
            }
        } else {
            // Clear device token registration
            deviceToken = nil
            isRegistered = false
        }
    }

    private func getDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            locale: Locale.current.identifier
        )
    }

    private func savePreferences(_ preferences: NotificationPreferences) async {
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        }
    }

    private func loadPreferences() -> NotificationPreferences {
        guard
            let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
            let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences()
        }
        return preferences
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            handleNotificationResponse(response)
        }
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        guard
            let typeString = userInfo["type"] as? String,
            let type = NotificationType(rawValue: typeString) else {
            return
        }

        // Create notification info
        let notificationInfo = NotificationInfo(
            id: response.notification.request.identifier,
            type: type,
            action: response.actionIdentifier,
            userInfo: userInfo
        )

        // Notify handlers
        if let handlers = notificationHandlers[type] {
            for handler in handlers {
                handler.handler(notificationInfo)
            }
        }

        // Handle specific actions
        switch response.actionIdentifier {
        case "VIEW_INSIGHT":
            handleViewInsightAction(userInfo)
        case "START_PAT":
            handleStartPATAction(userInfo)
        case "SNOOZE":
            handleSnoozeAction(response.notification.request)
        default:
            break
        }
    }

    private func handleViewInsightAction(_ userInfo: [AnyHashable: Any]) {
        guard let insightId = userInfo["insightId"] as? String else { return }

        // Post notification to navigate to insight
        NotificationCenter.default.post(
            name: .navigateToInsight,
            object: nil,
            userInfo: ["insightId": insightId]
        )
    }

    private func handleStartPATAction(_ userInfo: [AnyHashable: Any]) {
        // Post notification to start PAT
        NotificationCenter.default.post(name: .startPATAnalysis, object: nil)
    }

    private func handleSnoozeAction(_ request: UNNotificationRequest) {
        Task {
            // Reschedule for 1 hour later
            var newRequest = NotificationRequest(
                id: UUID().uuidString,
                title: request.content.title,
                body: request.content.body,
                trigger: .interval(3600, repeats: false),
                category: .patReminder
            )

            newRequest.userInfo = request.content.userInfo

            try? await scheduleLocalNotification(newRequest)
        }
    }
}

// MARK: - Supporting Types

enum NotificationType: String, CaseIterable, Codable {
    case healthInsight = "health_insight"
    case patReminder = "pat_reminder"
    case healthAlert = "health_alert"
    case syncComplete = "sync_complete"
    case systemUpdate = "system_update"
}

struct NotificationRequest {
    let id: String
    let title: String
    let body: String
    var subtitle: String?
    var badge: Int?
    var sound: String?
    let trigger: NotificationTrigger
    let category: NotificationCategory
    var userInfo: [AnyHashable: Any] = [:]
    var attachments: [NotificationAttachment]?

    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        trigger: NotificationTrigger = .immediate,
        category: NotificationCategory = .general
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.trigger = trigger
        self.category = category
    }
}

enum NotificationTrigger {
    case immediate
    case scheduled(Date)
    case interval(TimeInterval, repeats: Bool)
    case daily(hour: Int, minute: Int)
}

enum NotificationCategory {
    case general
    case insightNotification
    case healthAlert
    case patReminder

    var identifier: String {
        switch self {
        case .general:
            ""
        case .insightNotification:
            "INSIGHT_NOTIFICATION"
        case .healthAlert:
            "HEALTH_ALERT"
        case .patReminder:
            "PAT_REMINDER"
        }
    }
}

struct NotificationAttachment {
    let identifier: String
    let data: Data
    let type: AttachmentType
    let options: [String: Any]?
}

enum AttachmentType {
    case image
    case video
    case audio

    var fileExtension: String {
        switch self {
        case .image: "jpg"
        case .video: "mp4"
        case .audio: "mp3"
        }
    }
}

typealias NotificationHandler = (NotificationInfo) -> Void

struct NotificationInfo {
    let id: String
    let type: NotificationType
    let action: String
    let userInfo: [AnyHashable: Any]
}

private struct NotificationHandlerWrapper {
    let id: UUID
    let handler: NotificationHandler
}

struct NotificationPreferences: Codable {
    var enabledTypes: Set<NotificationType> = Set(NotificationType.allCases)
    var quietHoursEnabled = false
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    var soundEnabled = true
    var vibrationEnabled = true
    var criticalAlertsEnabled = true

    // Type-specific preferences
    var insightNotifications = InsightNotificationPreferences()
    var healthAlerts = HealthAlertPreferences()
    var patReminders = PATReminderPreferences()
}

struct InsightNotificationPreferences: Codable {
    var enabled = true
    var onlyHighPriority = false
    var categories: Set<String> = []
}

struct HealthAlertPreferences: Codable {
    var enabled = true
    var thresholdAlerts = true
    var trendAlerts = true
    var anomalyAlerts = true
}

struct PATReminderPreferences: Codable {
    var enabled = true
    var reminderTime: Date?
    var frequency: ReminderFrequency = .daily
}

enum ReminderFrequency: String, Codable {
    case daily
    case weekly
    case biweekly
    case monthly
}

// MARK: - DTO Types

struct DeviceTokenRegistrationRequest: Codable {
    let userId: String
    let token: String
    let platform: String
    let deviceInfo: DeviceInfo
}

struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let appVersion: String
    let locale: String
}

struct NotificationPreferencesRequest: Codable {
    let userId: String
    let preferences: NotificationPreferences
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let navigateToInsight = Notification.Name("navigateToInsight")
    static let startPATAnalysis = Notification.Name("startPATAnalysis")
    static let notificationSettingsChanged = Notification.Name("notificationSettingsChanged")
}
