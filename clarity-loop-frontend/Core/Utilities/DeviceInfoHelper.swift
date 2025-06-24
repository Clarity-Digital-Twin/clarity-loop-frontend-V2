import Foundation
import UIKit

/// Helper for generating device information for API requests
enum DeviceInfoHelper {
    /// Sanitize string to prevent JSON encoding issues
    private static func sanitizeString(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "") // Remove backslashes
            .replacingOccurrences(of: "\"", with: "") // Remove quotes
            .replacingOccurrences(of: "'", with: "") // Remove single quotes
            .replacingOccurrences(of: "\n", with: " ") // Replace newlines with space
            .replacingOccurrences(of: "\r", with: " ") // Replace carriage returns
            .replacingOccurrences(of: "\t", with: " ") // Replace tabs
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate device info dictionary for login requests
    static func generateDeviceInfo() -> [String: AnyCodable] {
        var deviceInfo: [String: AnyCodable] = [:]

        // Device ID
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        deviceInfo["device_id"] = AnyCodable(sanitizeString(deviceId))

        // Platform
        deviceInfo["platform"] = AnyCodable("iOS")

        // OS Version (just the version number as backend expects)
        deviceInfo["os_version"] = AnyCodable(sanitizeString(UIDevice.current.systemVersion))

        // App Version
        var appVersion = "1.0.0"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                appVersion = "\(version) (\(buildNumber))"
            } else {
                appVersion = version
            }
        }
        deviceInfo["app_version"] = AnyCodable(sanitizeString(appVersion))

        // Device Model
        deviceInfo["model"] = AnyCodable(sanitizeString(UIDevice.current.model))

        // Device Name (heavily sanitized)
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "'s", with: "") // Smart apostrophe variant
        deviceInfo["name"] = AnyCodable(sanitizeString(deviceName))

        return deviceInfo
    }

    /// Generate minimal device info for testing
    static func generateMinimalDeviceInfo() -> [String: AnyCodable] {
        [
            "device_id": AnyCodable("test-device"),
            "os_version": AnyCodable("iOS 18.0"),
            "app_version": AnyCodable("1.0.0"),
        ]
    }
}
