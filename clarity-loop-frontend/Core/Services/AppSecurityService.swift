import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AppSecurityService {
    // MARK: - Properties

    var isAppObscured = false
    var shouldBlurOnBackground = true
    var isJailbroken = false

    private var blurView: UIView?

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
        checkDeviceSecurity()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func enableBackgroundBlur(_ enabled: Bool) {
        shouldBlurOnBackground = enabled
        UserDefaults.standard.set(enabled, forKey: "background_blur_enabled")
    }

    func checkDeviceSecurity() {
        isJailbroken = isDeviceJailbroken()
    }

    var securityWarnings: [SecurityWarning] {
        var warnings: [SecurityWarning] = []

        if isJailbroken {
            warnings.append(SecurityWarning(
                type: .jailbreak,
                title: "Device Security Risk",
                message: "This device appears to be jailbroken, which may compromise the security of your health data.",
                severity: .high
            ))
        }

        return warnings
    }

    var isSecurityCompromised: Bool {
        isJailbroken
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Load settings
        shouldBlurOnBackground = UserDefaults.standard.bool(forKey: "background_blur_enabled")
        if UserDefaults.standard.object(forKey: "background_blur_enabled") == nil {
            shouldBlurOnBackground = true // Default to enabled
        }
    }

    @objc private func appWillResignActive() {
        if shouldBlurOnBackground {
            addBlurOverlay()
        }
        isAppObscured = true
    }

    @objc private func appDidBecomeActive() {
        removeBlurOverlay()
        isAppObscured = false
    }

    private func addBlurOverlay() {
        guard
            let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: { $0.isKeyWindow }) else { return }

        removeBlurOverlay() // Remove any existing overlay

        // Create blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = window.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add app logo/icon in center
        let logoImageView = UIImageView()
        logoImageView.image = UIImage(named: "AppIcon") ?? UIImage(systemName: "heart.fill")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.tintColor = .systemBlue
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        blurEffectView.contentView.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: blurEffectView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: blurEffectView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
        ])

        // Add app name label
        let appNameLabel = UILabel()
        appNameLabel.text = "Clarity Pulse"
        appNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        appNameLabel.textColor = .label
        appNameLabel.textAlignment = .center
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false

        blurEffectView.contentView.addSubview(appNameLabel)

        NSLayoutConstraint.activate([
            appNameLabel.centerXAnchor.constraint(equalTo: blurEffectView.centerXAnchor),
            appNameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
        ])

        window.addSubview(blurEffectView)
        blurView = blurEffectView
    }

    private func removeBlurOverlay() {
        blurView?.removeFromSuperview()
        blurView = nil
    }

    private func isDeviceJailbroken() -> Bool {
        // Check for common jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/private/var/cache/apt/",
            "/private/var/lib/apt",
            "/private/var/Users/",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/sbin/sshd",
            "/etc/ssh/sshd_config",
            "/private/etc/ssh/sshd_config",
            "/usr/libexec/ssh-keysign",
            "/bin/sh",
            "/etc/apt",
            "/usr/bin/ssh",
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if we can write to system directories
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // Should not be able to write here on non-jailbroken device
        } catch {
            // Good, we can't write to system directories
        }

        // Check for suspicious environment variables
        if let path = getenv("PATH") {
            let pathString = String(cString: path)
            if pathString.contains("/usr/bin") || pathString.contains("/bin") {
                // This might indicate jailbreak, but could also be normal
                // We'll be conservative and not flag this alone
            }
        }

        return false
    }
}

// MARK: - Supporting Types

struct SecurityWarning: Identifiable {
    let id = UUID()
    let type: SecurityWarningType
    let title: String
    let message: String
    let severity: SecuritySeverity
}

enum SecurityWarningType {
    case jailbreak
    case debugger
    case simulator
    case other
}

enum SecuritySeverity {
    case low
    case medium
    case high
    case critical

    var color: Color {
        switch self {
        case .low: .blue
        case .medium: .orange
        case .high: .red
        case .critical: .purple
        }
    }
}
