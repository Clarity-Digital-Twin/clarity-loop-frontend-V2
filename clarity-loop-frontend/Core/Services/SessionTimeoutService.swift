import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class SessionTimeoutService {
    // MARK: - Properties

    var isSessionLocked = false
    var timeoutInterval: TimeInterval = 900 // 15 minutes default
    var lastActivityDate = Date()

    private var timeoutTimer: Timer?
    private var backgroundDate: Date?

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
        resetActivityTimer()
    }

    deinit {
        timeoutTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func recordUserActivity() {
        lastActivityDate = Date()

        if isSessionLocked {
            // Don't reset timer if session is locked
            return
        }

        resetActivityTimer()
    }

    func lockSession() {
        isSessionLocked = true
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    func unlockSession() {
        isSessionLocked = false
        recordUserActivity()
    }

    func setTimeoutInterval(_ interval: TimeInterval) {
        timeoutInterval = interval
        if !isSessionLocked {
            resetActivityTimer()
        }
    }

    func getTimeoutOptions() -> [TimeoutOption] {
        [
            TimeoutOption(title: "1 minute", interval: 60),
            TimeoutOption(title: "5 minutes", interval: 300),
            TimeoutOption(title: "15 minutes", interval: 900),
            TimeoutOption(title: "30 minutes", interval: 1800),
            TimeoutOption(title: "1 hour", interval: 3600),
            TimeoutOption(title: "Never", interval: 0),
        ]
    }

    var timeUntilTimeout: TimeInterval {
        guard !isSessionLocked, timeoutInterval > 0 else { return 0 }

        let elapsed = Date().timeIntervalSince(lastActivityDate)
        return max(0, timeoutInterval - elapsed)
    }

    var isTimeoutEnabled: Bool {
        timeoutInterval > 0
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func resetActivityTimer() {
        timeoutTimer?.invalidate()

        guard timeoutInterval > 0 else { return }

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSessionTimeout()
            }
        }
    }

    private func handleSessionTimeout() {
        guard !isSessionLocked else { return }

        lockSession()

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .sessionDidTimeout,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        backgroundDate = Date()
    }

    @objc private func appWillEnterForeground() {
        guard let backgroundDate else { return }

        let backgroundDuration = Date().timeIntervalSince(backgroundDate)

        // If app was in background for more than 30 seconds, lock session
        if backgroundDuration > 30 {
            lockSession()
        }

        self.backgroundDate = nil
    }

    @objc private func appDidBecomeActive() {
        // Record activity when app becomes active
        if !isSessionLocked {
            recordUserActivity()
        }
    }
}

// MARK: - Supporting Types

struct TimeoutOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let interval: TimeInterval
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionDidTimeout = Notification.Name("sessionDidTimeout")
}

// MARK: - View Modifier for Activity Tracking

// Note: Environment key for sessionTimeoutService needs to be added to EnvironmentKeys.swift

extension View {
    func trackUserActivity() -> some View {
        self // Placeholder - will be implemented when environment key is added
    }
}
