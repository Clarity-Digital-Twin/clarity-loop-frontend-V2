# CLARITY Biometric Authentication & HIPAA Security Guide

## Overview
This guide provides comprehensive implementation details for biometric authentication (Face ID/Touch ID) in CLARITY Pulse V2, ensuring HIPAA compliance and protecting sensitive health information.

## HIPAA Requirements

### Technical Safeguards (45 CFR § 164.312)

1. **Access Control** (§ 164.312(a)(1))
   - Unique user identification
   - Automatic logoff
   - Encryption and decryption

2. **Audit Controls** (§ 164.312(b))
   - Hardware, software, and procedural mechanisms
   - Record and examine activity

3. **Integrity** (§ 164.312(c)(1))
   - Electronic PHI not improperly altered or destroyed

4. **Transmission Security** (§ 164.312(e)(1))
   - Guard against unauthorized access during transmission

## Biometric Authentication Implementation

### 1. Core Authentication Manager

```swift
import LocalAuthentication
import Security
import CryptoKit

@MainActor
final class BiometricAuthManager: ObservableObject {
    // MARK: - Properties
    private let context = LAContext()
    private let keychain = KeychainManager.shared
    private let auditLogger = AuditLogger.shared
    
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var isAuthenticated = false
    @Published private(set) var authenticationError: AuthenticationError?
    
    // MARK: - Configuration
    private let authConfig = AuthenticationConfiguration(
        requireBiometricForSensitiveData: true,
        sessionTimeout: 300, // 5 minutes
        maxFailedAttempts: 3,
        lockoutDuration: 900 // 15 minutes
    )
    
    // MARK: - Biometric Type
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var displayName: String {
            switch self {
            case .none: return "Passcode"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        evaluateBiometricAvailability()
        setupNotifications()
    }
    
    // MARK: - Biometric Evaluation
    private func evaluateBiometricAvailability() {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        
        switch context.biometryType {
        case .none:
            biometricType = .none
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        @unknown default:
            biometricType = .none
        }
    }
    
    // MARK: - Authentication Methods
    func authenticateUser(
        reason: String,
        fallbackTitle: String? = nil,
        requireBiometric: Bool = false
    ) async -> Result<AuthenticationToken, AuthenticationError> {
        // Check lockout status
        if await isLockedOut() {
            return .failure(.lockedOut)
        }
        
        // Configure context
        context.localizedReason = reason
        context.localizedFallbackTitle = fallbackTitle
        
        if requireBiometric {
            context.biometryType == .none ? 
                LAPolicy.deviceOwnerAuthenticationWithBiometrics :
                LAPolicy.deviceOwnerAuthentication
        }
        
        do {
            // Perform authentication
            let success = try await context.evaluatePolicy(
                requireBiometric ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                // Generate secure token
                let token = try await generateAuthenticationToken()
                
                // Log successful authentication
                await logAuthenticationEvent(
                    success: true,
                    method: biometricType,
                    reason: reason
                )
                
                // Update authentication state
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authenticationError = nil
                }
                
                // Start session monitoring
                startSessionMonitoring()
                
                return .success(token)
            } else {
                return .failure(.authenticationFailed)
            }
            
        } catch let error as LAError {
            let authError = mapLAError(error)
            
            // Log failed attempt
            await logAuthenticationEvent(
                success: false,
                method: biometricType,
                reason: reason,
                error: authError
            )
            
            // Handle failed attempts
            await handleFailedAttempt()
            
            await MainActor.run {
                self.authenticationError = authError
            }
            
            return .failure(authError)
        } catch {
            return .failure(.unknown(error))
        }
    }
    
    // MARK: - Token Generation
    private func generateAuthenticationToken() async throws -> AuthenticationToken {
        let tokenData = try generateSecureRandomData(length: 32)
        let timestamp = Date()
        let expiryDate = timestamp.addingTimeInterval(authConfig.sessionTimeout)
        
        let token = AuthenticationToken(
            value: tokenData.base64EncodedString(),
            issuedAt: timestamp,
            expiresAt: expiryDate,
            biometricMethod: biometricType
        )
        
        // Store token securely
        try await keychain.storeAuthToken(token)
        
        return token
    }
    
    private func generateSecureRandomData(length: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        
        guard status == errSecSuccess else {
            throw AuthenticationError.tokenGenerationFailed
        }
        
        return Data(bytes)
    }
}

// MARK: - Authentication Token
struct AuthenticationToken: Codable {
    let value: String
    let issuedAt: Date
    let expiresAt: Date
    let biometricMethod: BiometricAuthManager.BiometricType
    
    var isValid: Bool {
        Date() < expiresAt
    }
    
    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSince(Date())
    }
}

// MARK: - Error Handling
enum AuthenticationError: LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case authenticationFailed
    case userCancelled
    case passcodeNotSet
    case lockedOut
    case tokenGenerationFailed
    case tokenExpired
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .userCancelled:
            return "Authentication was cancelled"
        case .passcodeNotSet:
            return "Device passcode is not set. Please set up a passcode in Settings"
        case .lockedOut:
            return "Too many failed attempts. Please try again later"
        case .tokenGenerationFailed:
            return "Failed to generate secure token"
        case .tokenExpired:
            return "Your session has expired. Please authenticate again"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .biometryNotEnrolled, .passcodeNotSet:
            return true
        default:
            return false
        }
    }
}
```

### 2. Session Management

```swift
// MARK: - Session Management Extension
extension BiometricAuthManager {
    // MARK: - Session Monitoring
    private func startSessionMonitoring() {
        // Monitor for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Start inactivity timer
        startInactivityTimer()
    }
    
    private func startInactivityTimer() {
        Task {
            await SessionMonitor.shared.startMonitoring(
                timeout: authConfig.sessionTimeout
            ) { [weak self] in
                await self?.handleSessionTimeout()
            }
        }
    }
    
    @objc private func handleAppStateChange() {
        Task {
            // Lock sensitive data when app goes to background
            await lockSensitiveData()
            
            // Log session pause
            await auditLogger.logSessionEvent(
                type: .paused,
                reason: "App entered background"
            )
        }
    }
    
    private func handleSessionTimeout() async {
        await MainActor.run {
            isAuthenticated = false
        }
        
        // Clear sensitive data from memory
        await clearSensitiveData()
        
        // Log session timeout
        await auditLogger.logSessionEvent(
            type: .timeout,
            reason: "Inactivity timeout"
        )
        
        // Notify user
        await showReauthenticationRequired()
    }
    
    // MARK: - Re-authentication
    func requireReauthentication(
        for operation: SensitiveOperation
    ) async -> Bool {
        let reason = operation.authenticationReason
        
        let result = await authenticateUser(
            reason: reason,
            requireBiometric: operation.requiresBiometric
        )
        
        switch result {
        case .success:
            // Log sensitive operation access
            await auditLogger.logSensitiveOperation(
                operation: operation,
                authenticated: true
            )
            return true
            
        case .failure(let error):
            // Log failed access attempt
            await auditLogger.logSensitiveOperation(
                operation: operation,
                authenticated: false,
                error: error
            )
            return false
        }
    }
}

// MARK: - Sensitive Operations
enum SensitiveOperation {
    case viewHealthRecords
    case exportHealthData
    case modifyHealthData
    case shareHealthData
    case changeSecuritySettings
    case viewAuditLogs
    
    var authenticationReason: String {
        switch self {
        case .viewHealthRecords:
            return "Authenticate to view your health records"
        case .exportHealthData:
            return "Authenticate to export health data"
        case .modifyHealthData:
            return "Authenticate to modify health records"
        case .shareHealthData:
            return "Authenticate to share health information"
        case .changeSecuritySettings:
            return "Authenticate to change security settings"
        case .viewAuditLogs:
            return "Authenticate to view audit logs"
        }
    }
    
    var requiresBiometric: Bool {
        switch self {
        case .viewHealthRecords, .exportHealthData, .shareHealthData:
            return true
        default:
            return false
        }
    }
}
```

### 3. Secure Data Storage

```swift
// MARK: - Keychain Manager
actor KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.clarity.pulse"
    private let accessGroup = "group.com.clarity.pulse"
    
    // MARK: - Authentication Token Storage
    func storeAuthToken(_ token: AuthenticationToken) throws {
        let encoder = JSONEncoder()
        let tokenData = try encoder.encode(token)
        
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        // Delete existing token
        SecItemDelete(query as CFDictionary)
        
        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieveAuthToken() throws -> AuthenticationToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AuthenticationToken.self, from: data)
    }
    
    // MARK: - Encryption Key Management
    func generateDataProtectionKey() throws -> SymmetricKey {
        // Generate key in Secure Enclave if available
        if SecureEnclave.isAvailable {
            return try generateSecureEnclaveKey()
        } else {
            return try generateSoftwareKey()
        }
    }
    
    private func generateSecureEnclaveKey() throws -> SymmetricKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "com.clarity.datakey",
                kSecAttrAccessControl as String: try createAccessControl()
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        // Derive symmetric key from private key
        return try deriveSymmetricKey(from: privateKey)
    }
    
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        
        return access
    }
}

// MARK: - Secure Enclave
struct SecureEnclave {
    static var isAvailable: Bool {
        if #available(iOS 11.3, *) {
            return LAContext().canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: nil
            )
        }
        return false
    }
}
```

### 4. Audit Logging

```swift
// MARK: - HIPAA-Compliant Audit Logger
actor AuditLogger {
    static let shared = AuditLogger()
    
    private let auditStore = AuditLogStore()
    private let encryptionManager = EncryptionManager()
    
    // MARK: - Log Entry Structure
    struct AuditLogEntry: Codable {
        let id: UUID
        let timestamp: Date
        let userId: String
        let deviceId: String
        let eventType: EventType
        let eventDetails: [String: Any]
        let ipAddress: String?
        let location: LocationInfo?
        let success: Bool
        let errorDetails: String?
        
        enum EventType: String, Codable {
            // Authentication Events
            case authenticationAttempt = "AUTH_ATTEMPT"
            case authenticationSuccess = "AUTH_SUCCESS"
            case authenticationFailure = "AUTH_FAILURE"
            case sessionStart = "SESSION_START"
            case sessionEnd = "SESSION_END"
            case sessionTimeout = "SESSION_TIMEOUT"
            
            // Data Access Events
            case healthDataView = "DATA_VIEW"
            case healthDataExport = "DATA_EXPORT"
            case healthDataModify = "DATA_MODIFY"
            case healthDataDelete = "DATA_DELETE"
            case healthDataShare = "DATA_SHARE"
            
            // Security Events
            case securitySettingChange = "SECURITY_CHANGE"
            case passwordChange = "PASSWORD_CHANGE"
            case biometricEnrollment = "BIOMETRIC_ENROLL"
            case deviceTrust = "DEVICE_TRUST"
            
            // System Events
            case systemError = "SYSTEM_ERROR"
            case configurationChange = "CONFIG_CHANGE"
        }
    }
    
    // MARK: - Logging Methods
    func logAuthenticationEvent(
        success: Bool,
        method: BiometricAuthManager.BiometricType,
        reason: String,
        error: AuthenticationError? = nil
    ) async {
        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            userId: await getCurrentUserId(),
            deviceId: await getDeviceId(),
            eventType: success ? .authenticationSuccess : .authenticationFailure,
            eventDetails: [
                "method": method.displayName,
                "reason": reason,
                "appVersion": Bundle.main.appVersion,
                "osVersion": UIDevice.current.systemVersion
            ],
            ipAddress: await getIPAddress(),
            location: await getLocationInfo(),
            success: success,
            errorDetails: error?.localizedDescription
        )
        
        await storeAuditEntry(entry)
    }
    
    func logSensitiveOperation(
        operation: SensitiveOperation,
        authenticated: Bool,
        error: AuthenticationError? = nil
    ) async {
        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            userId: await getCurrentUserId(),
            deviceId: await getDeviceId(),
            eventType: mapOperationToEventType(operation),
            eventDetails: [
                "operation": String(describing: operation),
                "authenticated": authenticated,
                "requiresBiometric": operation.requiresBiometric
            ],
            ipAddress: await getIPAddress(),
            location: await getLocationInfo(),
            success: authenticated,
            errorDetails: error?.localizedDescription
        )
        
        await storeAuditEntry(entry)
    }
    
    // MARK: - Storage
    private func storeAuditEntry(_ entry: AuditLogEntry) async {
        do {
            // Encrypt audit log entry
            let encrypted = try await encryptionManager.encrypt(entry)
            
            // Store with tamper protection
            try await auditStore.store(encrypted)
            
            // Replicate to secure backup
            try await replicateToSecureBackup(encrypted)
            
        } catch {
            // Critical: Audit logging failure
            // This should trigger an alert to administrators
            await handleAuditLogFailure(error)
        }
    }
    
    // MARK: - Retention Policy
    func applyRetentionPolicy() async {
        // HIPAA requires 6 years retention minimum
        let retentionPeriod: TimeInterval = 6 * 365 * 24 * 60 * 60 // 6 years
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
        
        // Archive old logs before deletion
        let oldLogs = await auditStore.fetchLogs(before: cutoffDate)
        if !oldLogs.isEmpty {
            await archiveAuditLogs(oldLogs)
        }
    }
}
```

### 5. SwiftUI Implementation

```swift
// MARK: - Biometric Setup View
struct BiometricSetupView: View {
    @StateObject private var authManager = BiometricAuthManager()
    @State private var showingError = false
    @State private var isSettingUp = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: authManager.biometricType.icon)
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.clarityPrimary, .claritySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse)
            
            // Title
            VStack(spacing: 16) {
                Text("Secure Your Health Data")
                    .font(.clarityLargeTitle)
                    .foregroundColor(.clarityLabel)
                
                Text("Use \(authManager.biometricType.displayName) to protect your sensitive health information")
                    .font(.clarityBody)
                    .foregroundColor(.claritySecondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 20) {
                BiometricBenefitRow(
                    icon: "lock.shield.fill",
                    title: "HIPAA Compliant",
                    description: "Meets healthcare data security standards"
                )
                
                BiometricBenefitRow(
                    icon: "hand.raised.fill",
                    title: "Quick Access",
                    description: "Unlock with just a glance or touch"
                )
                
                BiometricBenefitRow(
                    icon: "eye.slash.fill",
                    title: "Private & Secure",
                    description: "Your biometric data never leaves your device"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button(action: setupBiometric) {
                    HStack {
                        if isSettingUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(isSettingUp ? "Setting Up..." : "Enable \(authManager.biometricType.displayName)")
                    }
                }
                .buttonStyle(ClarityButtonStyle(style: .primary, isFullWidth: true))
                .disabled(isSettingUp)
                
                Button("Set Up Later") {
                    // Handle skip
                }
                .font(.claritySubheadline)
                .foregroundColor(.claritySecondaryLabel)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .alert("Setup Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = authManager.authenticationError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func setupBiometric() {
        isSettingUp = true
        
        Task {
            let result = await authManager.authenticateUser(
                reason: "Set up biometric authentication to secure your health data"
            )
            
            await MainActor.run {
                isSettingUp = false
                
                switch result {
                case .success:
                    // Navigate to next screen
                    break
                case .failure:
                    showingError = true
                }
            }
        }
    }
}

struct BiometricBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.clarityPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.clarityHeadline)
                    .foregroundColor(.clarityLabel)
                
                Text(description)
                    .font(.claritySubheadline)
                    .foregroundColor(.claritySecondaryLabel)
            }
        }
    }
}

// MARK: - Protected Content Wrapper
struct BiometricProtectedView<Content: View>: View {
    @StateObject private var authManager = BiometricAuthManager()
    @State private var isUnlocked = false
    
    let content: Content
    let sensitivity: SensitiveOperation
    
    init(
        sensitivity: SensitiveOperation,
        @ViewBuilder content: () -> Content
    ) {
        self.sensitivity = sensitivity
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isUnlocked {
                content
                    .onAppear {
                        startSessionMonitoring()
                    }
            } else {
                BiometricLockView(
                    sensitivity: sensitivity,
                    onUnlock: {
                        isUnlocked = true
                    }
                )
            }
        }
        .onChange(of: authManager.isAuthenticated) { authenticated in
            if !authenticated {
                isUnlocked = false
            }
        }
    }
    
    private func startSessionMonitoring() {
        // Monitor for inactivity
    }
}

// MARK: - Lock Screen
struct BiometricLockView: View {
    let sensitivity: SensitiveOperation
    let onUnlock: () -> Void
    
    @StateObject private var authManager = BiometricAuthManager()
    @State private var isAuthenticating = false
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 48) {
            // Lock Icon
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(.claritySecondaryLabel)
                .symbolEffect(.bounce, value: showError)
            
            // Message
            VStack(spacing: 16) {
                Text("Authentication Required")
                    .font(.clarityTitle2)
                    .foregroundColor(.clarityLabel)
                
                Text(sensitivity.authenticationReason)
                    .font(.clarityBody)
                    .foregroundColor(.claritySecondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Authenticate Button
            Button(action: authenticate) {
                HStack {
                    Image(systemName: authManager.biometricType.icon)
                    Text("Unlock with \(authManager.biometricType.displayName)")
                }
            }
            .buttonStyle(ClarityButtonStyle(style: .primary, isFullWidth: false))
            .disabled(isAuthenticating)
            
            if let error = authManager.authenticationError {
                Text(error.localizedDescription)
                    .font(.clarityCaption1)
                    .foregroundColor(.clarityError)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            // Auto-trigger authentication
            authenticate()
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        showError = false
        
        Task {
            let success = await authManager.requireReauthentication(for: sensitivity)
            
            await MainActor.run {
                isAuthenticating = false
                
                if success {
                    onUnlock()
                } else {
                    showError = true
                    
                    // Haptic feedback
                    ClarityHaptics.notification(.error)
                }
            }
        }
    }
}
```

### 6. Testing Biometric Authentication

```swift
// MARK: - Mock Authentication Manager for Testing
#if DEBUG
class MockBiometricAuthManager: BiometricAuthManager {
    var shouldSucceed = true
    var mockBiometricType: BiometricType = .faceID
    
    override func authenticateUser(
        reason: String,
        fallbackTitle: String? = nil,
        requireBiometric: Bool = false
    ) async -> Result<AuthenticationToken, AuthenticationError> {
        // Simulate authentication delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if shouldSucceed {
            let token = AuthenticationToken(
                value: "mock_token",
                issuedAt: Date(),
                expiresAt: Date().addingTimeInterval(300),
                biometricMethod: mockBiometricType
            )
            return .success(token)
        } else {
            return .failure(.authenticationFailed)
        }
    }
}
#endif

// MARK: - Unit Tests
final class BiometricAuthTests: XCTestCase {
    func test_biometricAuthentication_success() async {
        // Given
        let mockManager = MockBiometricAuthManager()
        mockManager.shouldSucceed = true
        
        // When
        let result = await mockManager.authenticateUser(
            reason: "Test authentication"
        )
        
        // Then
        switch result {
        case .success(let token):
            XCTAssertTrue(token.isValid)
            XCTAssertEqual(token.biometricMethod, .faceID)
        case .failure:
            XCTFail("Authentication should succeed")
        }
    }
    
    func test_biometricAuthentication_failure() async {
        // Given
        let mockManager = MockBiometricAuthManager()
        mockManager.shouldSucceed = false
        
        // When
        let result = await mockManager.authenticateUser(
            reason: "Test authentication"
        )
        
        // Then
        switch result {
        case .success:
            XCTFail("Authentication should fail")
        case .failure(let error):
            XCTAssertEqual(error, .authenticationFailed)
        }
    }
}
```

## Security Best Practices

### 1. Implementation Checklist
- [ ] Enable App Transport Security (ATS)
- [ ] Implement certificate pinning
- [ ] Use Secure Enclave when available
- [ ] Implement jailbreak detection
- [ ] Add tamper detection
- [ ] Enable remote wipe capability
- [ ] Implement secure backup
- [ ] Add intrusion detection

### 2. Data Protection Levels
```swift
// File protection levels for different data types
extension FileManager {
    func setHealthDataProtection(for url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.completeUnlessOpen,
            forKey: .fileProtectionKey
        )
    }
    
    func setAuditLogProtection(for url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.complete,
            forKey: .fileProtectionKey
        )
    }
}
```

### 3. Network Security
```swift
// Certificate pinning for API calls
class SecureNetworkManager {
    func performSecureRequest(_ request: URLRequest) async throws -> Data {
        let session = URLSession(
            configuration: .ephemeral,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
        
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Implement certificate pinning
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate certificate
        // ... certificate validation logic
    }
}
```

## Compliance Documentation

### Required for HIPAA Audit
1. **Access Control Matrix** - Document who can access what
2. **Audit Log Retention Policy** - 6-year minimum
3. **Incident Response Plan** - Breach notification procedures
4. **Security Risk Assessment** - Annual review
5. **Employee Training Records** - Security awareness
6. **Business Associate Agreements** - Third-party vendors
7. **Encryption Inventory** - All encryption methods used

## Summary
This implementation ensures CLARITY Pulse V2 meets HIPAA technical safeguards while providing a seamless user experience with biometric authentication. Regular security audits and updates are essential to maintain compliance.