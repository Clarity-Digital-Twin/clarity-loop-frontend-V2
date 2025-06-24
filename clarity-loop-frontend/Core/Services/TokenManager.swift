import Foundation
import Security

/// Manages authentication tokens with secure Keychain storage
actor TokenManager {
    // MARK: - Singleton

    static let shared = TokenManager()

    // MARK: - Properties

    private let accessTokenKey = "com.novamindnyc.clarity.accessToken"
    private let refreshTokenKey = "com.novamindnyc.clarity.refreshToken"
    private let expiryDateKey = "com.novamindnyc.clarity.tokenExpiryDate"
    private let keychainService = "com.novamindnyc.clarity"

    private var tokenExpiryDate: Date?

    // MARK: - Initialization

    private init() {
        // Load expiry date from UserDefaults
        if let storedExpiry = UserDefaults.standard.object(forKey: expiryDateKey) as? Date {
            self.tokenExpiryDate = storedExpiry
        }
    }

    // MARK: - Public Methods

    /// Store tokens securely in Keychain
    func store(accessToken: String, refreshToken: String, expiresIn: Int) {
        // Store access token
        saveToKeychain(value: accessToken, key: accessTokenKey)

        // Store refresh token
        saveToKeychain(value: refreshToken, key: refreshTokenKey)

        // Calculate and store expiry date
        tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        UserDefaults.standard.set(tokenExpiryDate, forKey: expiryDateKey)
    }

    /// Get the access token if it exists
    func getAccessToken() -> String? {
        loadFromKeychain(key: accessTokenKey)
    }

    /// Get the refresh token if it exists
    func getRefreshToken() -> String? {
        loadFromKeychain(key: refreshTokenKey)
    }

    /// Get the remaining time until token expiry in seconds
    func getTokenExpiryTime() -> Int {
        guard let expiryDate = tokenExpiryDate else { return 0 }
        let timeRemaining = expiryDate.timeIntervalSinceNow
        return max(0, Int(timeRemaining))
    }

    /// Check if the token is expired or about to expire (within 60 seconds)
    func isTokenExpired() -> Bool {
        getTokenExpiryTime() <= 60
    }

    /// Clear all stored tokens
    func clear() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        tokenExpiryDate = nil
        UserDefaults.standard.removeObject(forKey: expiryDateKey)
    }

    // MARK: - Private Keychain Methods

    private func saveToKeychain(value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("❌ TokenManager: Failed to save \(key) to Keychain. Status: \(status)")
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if
            status == errSecSuccess,
            let data = result as? Data,
            let string = String(data: data, encoding: .utf8) {
            return string
        }

        return nil
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Non-Actor Extensions

extension TokenManager {
    /// Synchronous check if we have valid tokens (for UI updates)
    nonisolated var hasValidTokens: Bool {
        get async {
            let hasAccess = await getAccessToken() != nil
            let hasRefresh = await getRefreshToken() != nil
            let notExpired = await !isTokenExpired()

            return hasAccess && hasRefresh && notExpired
        }
    }
}
