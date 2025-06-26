//
//  MockGenerator.swift
//  clarity-loop-frontend-v2Tests
//
//  Generates mock data for testing - follows Factory pattern
//

import Foundation
@testable import ClarityDomain
@testable import ClarityData

/// Generates mock data for testing
public final class MockGenerator {
    
    // MARK: - Properties
    
    private let randomSource: RandomNumberGenerator
    private let dateProvider: () -> Date
    
    // MARK: - Common test data
    
    private let firstNames = ["John", "Jane", "Alice", "Bob", "Charlie", "Diana", "Emma", "Frank", "Grace", "Henry"]
    private let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
    private let emailDomains = ["test.com", "example.com", "mock.io", "testmail.com"]
    
    // MARK: - Initialization
    
    /// Initialize with optional seed for deterministic generation
    public init(seed: Int? = nil, dateProvider: @escaping () -> Date = { Date() }) {
        if let seed = seed {
            self.randomSource = SeededRandomGenerator(seed: seed)
        } else {
            self.randomSource = SystemRandomNumberGenerator()
        }
        self.dateProvider = dateProvider
    }
    
    // MARK: - User Generation
    
    /// Generate a mock User
    public func generateUser(
        id: UUID = UUID(),
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) -> User {
        return User(
            id: id,
            email: email ?? randomEmail(),
            firstName: firstName ?? randomName(),
            lastName: lastName ?? randomName()
        )
    }
    
    /// Generate multiple mock Users
    public func generateUsers(count: Int) -> [User] {
        return (0..<count).map { index in
            generateUser(
                email: "user\(index)@\(emailDomains.randomElement()!)"
            )
        }
    }
    
    // MARK: - HealthMetric Generation
    
    /// Generate a mock HealthMetric
    public func generateHealthMetric(
        id: UUID = UUID(),
        type: HealthMetricType? = nil,
        userId: UUID? = nil,
        value: Double? = nil,
        source: HealthMetricSource? = nil
    ) -> HealthMetric {
        let metricType = type ?? HealthMetricType.allCases.randomElement()!
        let actualValue = value ?? generateRealisticValue(for: metricType)
        let actualUserId = userId ?? UUID()
        
        return HealthMetric(
            id: id,
            userId: actualUserId,
            type: metricType,
            value: actualValue,
            unit: metricType.defaultUnit,
            recordedAt: dateProvider(),
            source: source ?? .manual,
            notes: nil
        )
    }
    
    /// Generate multiple mock HealthMetrics
    public func generateHealthMetrics(count: Int, userId: UUID = UUID()) -> [HealthMetric] {
        return (0..<count).map { _ in
            generateHealthMetric(userId: userId)
        }
    }
    
    // MARK: - AuthToken Generation
    
    /// Generate a mock AuthToken (LoginResponse)
    public func generateAuthToken(userId: String? = nil) -> LoginResponseDTO {
        return LoginResponseDTO(
            accessToken: randomToken(length: 32),
            refreshToken: randomToken(length: 32),
            expiresIn: 3600,
            userId: userId ?? UUID().uuidString
        )
    }
    
    // MARK: - Random Data Generators
    
    /// Generate a random email address
    public func randomEmail() -> String {
        let username = randomString(length: 8).lowercased()
        let domain = emailDomains.randomElement()!
        return "\(username)@\(domain)"
    }
    
    /// Generate a random name
    public func randomName() -> String {
        return firstNames.randomElement()!
    }
    
    /// Generate a random phone number
    public func randomPhoneNumber() -> String {
        let areaCode = String(format: "%03d", Int.random(in: 200...999))
        let prefix = String(format: "%03d", Int.random(in: 200...999))
        let lineNumber = String(format: "%04d", Int.random(in: 0...9999))
        return "(\(areaCode)) \(prefix)-\(lineNumber)"
    }
    
    // MARK: - Private Helpers
    
    private func generateRealisticValue(for type: HealthMetricType) -> Double {
        switch type {
        case .heartRate:
            return Double.random(in: 60...100)
        case .steps:
            return Double.random(in: 1000...15000).rounded()
        case .sleepDuration:
            return Double.random(in: 6...9)
        case .bloodPressureSystolic:
            return Double.random(in: 110...130).rounded()
        case .bloodPressureDiastolic:
            return Double.random(in: 70...85).rounded()
        case .weight:
            return Double.random(in: 50...100)
        case .height:
            return Double.random(in: 150...200)
        case .bodyTemperature:
            return Double.random(in: 36.5...37.5)
        case .bloodGlucose:
            return Double.random(in: 80...120)
        case .oxygenSaturation:
            return Double.random(in: 95...100)
        case .respiratoryRate:
            return Double.random(in: 12...20).rounded()
        case .caloriesBurned:
            return Double.random(in: 200...800).rounded()
        case .waterIntake:
            return Double.random(in: 1...4)
        case .exerciseDuration:
            return Double.random(in: 0...120).rounded()
        case .custom:
            return Double.random(in: 0...100)
        }
    }
    
    /// Generate multiple health metrics with different types
    public func generateHealthMetrics(
        type: HealthMetricType,
        count: Int,
        userId: UUID? = nil
    ) -> [HealthMetric] {
        let actualUserId = userId ?? UUID()
        return (0..<count).map { _ in
            generateHealthMetric(type: type, userId: actualUserId)
        }
    }
    
    /// Generate health metrics by day
    public func generateHealthMetricsByDay(
        type: HealthMetricType,
        days: Int,
        userId: UUID? = nil
    ) -> [HealthMetric] {
        let actualUserId = userId ?? UUID()
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<days).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            return HealthMetric(
                userId: actualUserId,
                type: type,
                value: generateRealisticValue(for: type),
                unit: type.defaultUnit,
                recordedAt: date,
                source: .manual,
                notes: nil
            )
        }
    }
    
    /// Generate a random date within a range
    public func randomDate(daysAgo: Int = 30) -> Date {
        let now = Date()
        let secondsInDay = 86400.0
        let maxSecondsAgo = Double(daysAgo) * secondsInDay
        let randomSecondsAgo = Double.random(in: 0...maxSecondsAgo)
        return now.addingTimeInterval(-randomSecondsAgo)
    }
    
    public func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    private func randomToken(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - Seeded Random Generator

/// Random number generator with seed for deterministic testing
private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(seed)
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - LoginResponseDTO for Auth Token

public struct LoginResponseDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}