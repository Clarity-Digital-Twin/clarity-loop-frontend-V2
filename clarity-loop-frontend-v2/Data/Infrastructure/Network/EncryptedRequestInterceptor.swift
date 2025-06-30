//
//  EncryptedRequestInterceptor.swift
//  clarity-loop-frontend-v2
//
//  Request interceptor for encrypting sensitive health data
//

import Foundation
import ClarityCore
import ClarityDomain

// MARK: - DTOs for Health Metric Creation

struct CreateHealthMetricDTO: Codable {
    let userId: String
    let type: String
    let value: Double
    let unit: String
    let recordedAt: String
    let source: String?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type = "metric_type"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
        case notes
    }
}

/// Interceptor that encrypts sensitive health data before network transmission
public final class EncryptedRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    
    private let secureStorage: SecureStorageProtocol
    private let encryptionPaths: Set<String>
    
    /// Initialize with secure storage and paths that require encryption
    public init(
        secureStorage: SecureStorageProtocol,
        encryptionPaths: Set<String> = [
            "/api/v1/health-metrics",
            "/api/v1/health-metrics/batch",
            "/api/v1/medications",
            "/api/v1/allergies"
        ]
    ) {
        self.secureStorage = secureStorage
        self.encryptionPaths = encryptionPaths
    }
    
    public func intercept(_ request: inout URLRequest) async throws {
        // Check if this path requires encryption
        guard let url = request.url,
              shouldEncrypt(path: url.path) else {
            return
        }
        
        // Only encrypt POST/PUT/PATCH requests with body
        guard let httpMethod = request.httpMethod,
              ["POST", "PUT", "PATCH"].contains(httpMethod),
              let bodyData = request.httpBody else {
            return
        }
        
        // Try to determine content type
        if isHealthMetricData(bodyData) {
            let encryptedPayload = try await encryptHealthMetricData(bodyData)
            request.httpBody = encryptedPayload
            request.setValue("application/vnd.clarity.encrypted+json", forHTTPHeaderField: "Content-Type")
            request.setValue("AES-GCM-256", forHTTPHeaderField: "X-Encryption-Algorithm")
        }
    }
    
    private func shouldEncrypt(path: String) -> Bool {
        encryptionPaths.contains { path.hasPrefix($0) }
    }
    
    private func isHealthMetricData(_ data: Data) -> Bool {
        // Try to decode as health metric to verify
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try single metric
        if (try? decoder.decode(HealthMetric.self, from: data)) != nil {
            return true
        }
        
        // Try array of metrics
        if (try? decoder.decode([HealthMetric].self, from: data)) != nil {
            return true
        }
        
        // Try create/update DTOs
        if (try? decoder.decode(CreateHealthMetricDTO.self, from: data)) != nil {
            return true
        }
        
        return false
    }
    
    private func encryptHealthMetricData(_ data: Data) async throws -> Data {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Handle different data types
        if let metric = try? decoder.decode(HealthMetric.self, from: data) {
            // Single metric
            let secureStorage = self.secureStorage as! SecureStorage
            let payload = try await secureStorage.prepareForTransmission(metric)
            return try encoder.encode(payload)
            
        } else if let metrics = try? decoder.decode([HealthMetric].self, from: data) {
            // Multiple metrics
            let secureStorage = self.secureStorage as! SecureStorage
            var payloads: [EncryptedHealthPayload] = []
            
            for metric in metrics {
                let payload = try await secureStorage.prepareForTransmission(metric)
                payloads.append(payload)
            }
            
            return try encoder.encode(payloads)
            
        } else if var createDTO = try? decoder.decode(CreateHealthMetricDTO.self, from: data) {
            // Create DTO - encrypt the value field
            let secureStorage = self.secureStorage as! SecureStorage
            
            // Create temporary metric for encryption
            let userUuid = UUID(uuidString: createDTO.userId) ?? UUID()
            let dateFormatter = ISO8601DateFormatter()
            let recordedDate = dateFormatter.date(from: createDTO.recordedAt) ?? Date()
            let metricType = mapStringToHealthMetricType(createDTO.type)
            let metricSource = createDTO.source.flatMap { HealthMetricSource(rawValue: $0) }
            
            let tempMetric = HealthMetric(
                id: UUID(),
                userId: userUuid,
                type: metricType,
                value: createDTO.value,
                unit: createDTO.unit,
                recordedAt: recordedDate,
                source: metricSource,
                notes: createDTO.notes
            )
            
            let payload = try await secureStorage.prepareForTransmission(tempMetric)
            
            // Create encrypted DTO
            let encryptedDTO = EncryptedCreateHealthMetricDTO(
                userId: createDTO.userId,
                type: createDTO.type,
                encryptedPayload: payload,
                unit: createDTO.unit,
                recordedAt: createDTO.recordedAt,
                source: createDTO.source
            )
            
            return try encoder.encode(encryptedDTO)
        }
        
        // If we can't identify the data type, return as-is
        return data
    }
    
    private func mapStringToHealthMetricType(_ type: String) -> HealthMetricType {
        switch type {
        case "heart_rate":
            return .heartRate
        case "blood_pressure_systolic":
            return .bloodPressureSystolic
        case "blood_pressure_diastolic":
            return .bloodPressureDiastolic
        case "blood_glucose":
            return .bloodGlucose
        case "weight":
            return .weight
        case "height":
            return .height
        case "body_temperature":
            return .bodyTemperature
        case "oxygen_saturation":
            return .oxygenSaturation
        case "steps":
            return .steps
        case "sleep_duration":
            return .sleepDuration
        case "respiratory_rate":
            return .respiratoryRate
        case "calories_burned":
            return .caloriesBurned
        case "water_intake":
            return .waterIntake
        case "exercise_duration":
            return .exerciseDuration
        default:
            return .custom(type.replacingOccurrences(of: "_", with: " ").capitalized)
        }
    }
}

// MARK: - Encrypted DTOs

/// DTO for creating health metrics with encrypted values
struct EncryptedCreateHealthMetricDTO: Codable {
    let userId: String
    let type: String
    let encryptedPayload: EncryptedHealthPayload
    let unit: String
    let recordedAt: String
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type = "metric_type"
        case encryptedPayload = "encrypted_payload"
        case unit
        case recordedAt = "recorded_at"
        case source
    }
}

// MARK: - Response Decryption

/// Response handler for decrypting encrypted health data
public final class EncryptedResponseHandler: @unchecked Sendable {
    
    private let secureStorage: SecureStorageProtocol
    
    public init(secureStorage: SecureStorageProtocol) {
        self.secureStorage = secureStorage
    }
    
    /// Decrypt response data if it contains encrypted health metrics
    public func handleResponse(_ data: Data, response: URLResponse) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse,
              let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("application/vnd.clarity.encrypted+json") else {
            return data
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let secureStorage = self.secureStorage as! SecureStorage
        
        // Try to decode as encrypted payload
        if let payload = try? decoder.decode(EncryptedHealthPayload.self, from: data) {
            // Single encrypted metric
            let decrypted = try await decryptPayload(payload, using: secureStorage)
            return try encoder.encode(decrypted)
            
        } else if let payloads = try? decoder.decode([EncryptedHealthPayload].self, from: data) {
            // Multiple encrypted metrics
            var decryptedMetrics: [HealthMetric] = []
            
            for payload in payloads {
                let metric = try await decryptPayload(payload, using: secureStorage)
                decryptedMetrics.append(metric)
            }
            
            return try encoder.encode(decryptedMetrics)
        }
        
        // Return as-is if not encrypted
        return data
    }
    
    private func decryptPayload(
        _ payload: EncryptedHealthPayload,
        using secureStorage: SecureStorage
    ) async throws -> HealthMetric {
        // Reconstruct encrypted data from payload
        guard let ciphertext = Data(base64Encoded: payload.encryptedData),
              let nonceData = Data(base64Encoded: payload.nonce) else {
            throw SecureStorageError.decryptionFailed("Invalid base64 encoding")
        }
        
        // Combine nonce + ciphertext for decryption
        var combinedData = nonceData
        combinedData.append(ciphertext)
        
        return try await secureStorage.decryptHealthMetric(from: combinedData)
    }
}
