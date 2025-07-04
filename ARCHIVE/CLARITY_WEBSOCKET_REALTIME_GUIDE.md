# CLARITY WebSocket & Real-Time Implementation Guide

## Overview
This document provides complete implementation details for WebSocket connections and real-time features in CLARITY Pulse, ensuring reliable bi-directional communication with the backend.

## WebSocket Architecture

### Core Components

```swift
// WebSocketManager.swift
@Observable
final class WebSocketManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let baseURL: String
    private let authService: AuthServiceProtocol
    
    // State management
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
    // Ping/Pong for keep-alive
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval = 30.0
    
    init(authService: AuthServiceProtocol) {
        self.authService = authService
        self.baseURL = Configuration.wsBaseURL
        self.session = URLSession(configuration: .default)
    }
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
}
```

### Connection Management

```swift
extension WebSocketManager {
    func connect() async throws {
        guard connectionState != .connected else { return }
        
        connectionState = .connecting
        
        // Get auth token
        guard let token = try await authService.getValidToken() else {
            throw WebSocketError.authenticationRequired
        }
        
        // Create WebSocket URL with auth
        var request = URLRequest(url: URL(string: "\(baseURL)/ws")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Create WebSocket task
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping timer
        startPingTimer()
        
        connectionState = .connected
        reconnectAttempts = 0
    }
    
    func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }
}
```

### Message Handling

```swift
// Message types
enum WebSocketMessage: Codable {
    case healthDataUpdate(HealthDataUpdateMessage)
    case notification(NotificationMessage)
    case syncRequest(SyncRequestMessage)
    case connectionAck(ConnectionAckMessage)
    case error(ErrorMessage)
}

// Message receiving
extension WebSocketManager {
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                self.handleConnectionError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            handleDataMessage(data)
        @unknown default:
            break
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(WebSocketMessage.self, from: data) else {
            return
        }
        
        Task { @MainActor in
            switch message {
            case .healthDataUpdate(let update):
                await handleHealthDataUpdate(update)
            case .notification(let notification):
                await handleNotification(notification)
            case .syncRequest(let request):
                await handleSyncRequest(request)
            case .connectionAck(let ack):
                handleConnectionAck(ack)
            case .error(let error):
                handleServerError(error)
            }
        }
    }
}
```

### Automatic Reconnection

```swift
extension WebSocketManager {
    private func handleConnectionError(_ error: Error) {
        connectionState = .failed(error)
        
        // Check if we should reconnect
        if shouldReconnect() {
            scheduleReconnect()
        } else {
            // Notify user of permanent failure
            notifyConnectionFailure()
        }
    }
    
    private func shouldReconnect() -> Bool {
        return reconnectAttempts < maxReconnectAttempts &&
               !isUserInitiatedDisconnect
    }
    
    private func scheduleReconnect() {
        connectionState = .reconnecting
        reconnectAttempts += 1
        
        // Exponential backoff
        let delay = reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                try await connect()
            } catch {
                handleConnectionError(error)
            }
        }
    }
}
```

### Keep-Alive Implementation

```swift
extension WebSocketManager {
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.handleConnectionError(error)
            }
        }
    }
}
```

## Real-Time Features Implementation

### Health Data Updates

```swift
// HealthDataUpdateHandler.swift
@Observable
final class HealthDataUpdateHandler {
    private let webSocketManager: WebSocketManager
    private let healthDataRepository: HealthDataRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    
    func handleHealthDataUpdate(_ update: HealthDataUpdateMessage) async {
        // Update local SwiftData
        do {
            try await healthDataRepository.updateFromRemote(update.data)
            
            // Notify UI if relevant
            if update.isUrgent {
                await notificationService.showUrgentUpdate(update)
            }
        } catch {
            // Handle update failure
            await handleUpdateFailure(update, error: error)
        }
    }
}
```

### Real-Time Notifications

```swift
// NotificationHandler.swift
@Observable
final class NotificationHandler {
    private let webSocketManager: WebSocketManager
    private let notificationCenter = UNUserNotificationCenter.current()
    
    func handleNotification(_ notification: NotificationMessage) async {
        switch notification.type {
        case .alert:
            await showAlertNotification(notification)
        case .badge:
            await updateBadge(notification)
        case .silent:
            await processSilentNotification(notification)
        }
    }
    
    private func showAlertNotification(_ notification: NotificationMessage) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
}
```

### Sync Coordination

```swift
// SyncCoordinator.swift
@Observable
final class SyncCoordinator {
    private let webSocketManager: WebSocketManager
    private let syncService: SyncServiceProtocol
    
    func handleSyncRequest(_ request: SyncRequestMessage) async {
        switch request.type {
        case .fullSync:
            await performFullSync()
        case .partialSync(let entities):
            await performPartialSync(entities: entities)
        case .conflictResolution(let conflicts):
            await resolveConflicts(conflicts)
        }
    }
    
    private func performFullSync() async {
        // Coordinate full sync through WebSocket
        do {
            let localData = try await syncService.prepareFullSyncData()
            let message = WebSocketMessage.syncResponse(localData)
            try await webSocketManager.send(message)
        } catch {
            // Handle sync failure
        }
    }
}
```

## WebSocket Message Types

### Incoming Messages

```swift
// Health data update
struct HealthDataUpdateMessage: Codable {
    let id: String
    let timestamp: Date
    let data: HealthDataDTO
    let isUrgent: Bool
    let source: DataSource
}

// Notification
struct NotificationMessage: Codable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: Any]?
}

// Sync request
struct SyncRequestMessage: Codable {
    let id: String
    let type: SyncType
    let entities: [String]?
    let lastSyncTimestamp: Date?
}

// Connection acknowledgment
struct ConnectionAckMessage: Codable {
    let sessionId: String
    let serverTime: Date
    let capabilities: [String]
}
```

### Outgoing Messages

```swift
// Send message helper
extension WebSocketManager {
    func send<T: Encodable>(_ message: T) async throws {
        let data = try JSONEncoder().encode(message)
        let string = String(data: data, encoding: .utf8)!
        
        try await webSocketTask?.send(.string(string))
    }
}

// Message types
struct SubscribeMessage: Codable {
    let type = "subscribe"
    let channels: [String]
}

struct UnsubscribeMessage: Codable {
    let type = "unsubscribe"
    let channels: [String]
}

struct SyncResponseMessage: Codable {
    let type = "syncResponse"
    let requestId: String
    let data: [String: Any]
}
```

## Error Handling

```swift
enum WebSocketError: LocalizedError {
    case authenticationRequired
    case connectionFailed(Error)
    case messageDecodingFailed
    case invalidMessageFormat
    case serverError(String)
    case reconnectExhausted
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required for WebSocket connection"
        case .connectionFailed(let error):
            return "WebSocket connection failed: \(error.localizedDescription)"
        case .messageDecodingFailed:
            return "Failed to decode WebSocket message"
        case .invalidMessageFormat:
            return "Invalid WebSocket message format"
        case .serverError(let message):
            return "Server error: \(message)"
        case .reconnectExhausted:
            return "Failed to reconnect after multiple attempts"
        }
    }
}
```

## Background Handling

```swift
// BackgroundWebSocketHandler.swift
final class BackgroundWebSocketHandler {
    private let webSocketManager: WebSocketManager
    private var backgroundTask: UIBackgroundTaskIdentifier?
    
    func handleAppBackground() {
        // Start background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Keep connection alive for critical updates
        Task {
            await webSocketManager.switchToBackgroundMode()
        }
    }
    
    func handleAppForeground() {
        // Restore full connection
        Task {
            await webSocketManager.switchToForegroundMode()
            await webSocketManager.requestMissedUpdates()
        }
        
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if let task = backgroundTask {
            UIApplication.shared.endBackgroundTask(task)
            backgroundTask = nil
        }
    }
}
```

## Testing WebSocket Connections

```swift
// MockWebSocketManager.swift
final class MockWebSocketManager: WebSocketManager {
    var mockMessages: [WebSocketMessage] = []
    var simulateDisconnect = false
    var simulateReconnectFailure = false
    
    override func connect() async throws {
        if simulateDisconnect {
            throw WebSocketError.connectionFailed(NSError(domain: "test", code: 1))
        }
        connectionState = .connected
    }
    
    func simulateMessage(_ message: WebSocketMessage) {
        // Simulate incoming message
        handleMockMessage(message)
    }
}

// WebSocket tests
final class WebSocketTests: XCTestCase {
    func test_connect_withValidAuth_shouldSucceed() async throws {
        // Given
        let mockAuth = MockAuthService()
        mockAuth.mockToken = "valid_token"
        let manager = WebSocketManager(authService: mockAuth)
        
        // When
        try await manager.connect()
        
        // Then
        XCTAssertEqual(manager.connectionState, .connected)
    }
    
    func test_connectionLoss_shouldReconnect() async throws {
        // Given
        let manager = MockWebSocketManager()
        try await manager.connect()
        
        // When
        manager.simulateDisconnect = true
        manager.simulateConnectionLoss()
        
        // Wait for reconnect
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Then
        XCTAssertEqual(manager.connectionState, .connected)
        XCTAssertEqual(manager.reconnectAttempts, 1)
    }
}
```

## Security Considerations

### Authentication
- Always send auth token in connection request
- Refresh token before it expires
- Handle auth failures gracefully

### Data Validation
- Validate all incoming messages
- Sanitize data before processing
- Never trust client-side only validation

### Encryption
- Use WSS (WebSocket Secure) only
- Certificate pinning for production
- No sensitive data in URLs

## Performance Optimization

### Message Batching
```swift
// Batch multiple updates
struct BatchedMessage: Codable {
    let messages: [WebSocketMessage]
    let batchId: String
    let timestamp: Date
}
```

### Compression
- Enable per-message deflate
- Compress large payloads
- Monitor bandwidth usage

### Connection Pooling
- Reuse connections when possible
- Implement connection limits
- Monitor connection health

## Monitoring & Metrics

```swift
// WebSocketMetrics.swift
struct WebSocketMetrics {
    var messagesReceived: Int = 0
    var messagesSent: Int = 0
    var reconnectCount: Int = 0
    var averageLatency: TimeInterval = 0
    var connectionUptime: TimeInterval = 0
    var lastError: Error?
}
```

## ⚠️ Common Pitfalls to Avoid

1. **Not handling reconnection properly** - Always implement exponential backoff
2. **Forgetting background handling** - WebSockets close in background
3. **No message ordering** - Messages may arrive out of order
4. **Missing error handling** - Network issues are common
5. **No connection state UI** - Users need to know connection status

---

✅ With this WebSocket implementation, CLARITY provides reliable real-time updates while handling all edge cases gracefully.