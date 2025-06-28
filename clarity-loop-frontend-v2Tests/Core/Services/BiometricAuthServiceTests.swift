//
//  BiometricAuthServiceTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for biometric authentication
//

import XCTest
import LocalAuthentication
@testable import ClarityCore

final class BiometricAuthServiceTests: XCTestCase {
    
    private var sut: BiometricAuthServiceProtocol!
    private var mockContext: MockLAContext!
    
    override func setUp() {
        super.setUp()
        mockContext = MockLAContext()
        sut = BiometricAuthService(context: mockContext)
    }
    
    override func tearDown() {
        sut = nil
        mockContext = nil
        super.tearDown()
    }
    
    // MARK: - Availability Tests
    
    func test_isBiometricAvailable_whenSupported_shouldReturnTrue() {
        // Given
        mockContext.canEvaluatePolicyResult = true
        
        // When
        let isAvailable = sut.isBiometricAvailable()
        
        // Then
        XCTAssertTrue(isAvailable)
    }
    
    func test_isBiometricAvailable_whenNotSupported_shouldReturnFalse() {
        // Given
        mockContext.canEvaluatePolicyResult = false
        mockContext.canEvaluatePolicyError = LAError(.biometryNotAvailable)
        
        // When
        let isAvailable = sut.isBiometricAvailable()
        
        // Then
        XCTAssertFalse(isAvailable)
    }
    
    func test_biometricType_whenFaceID_shouldReturnFaceID() {
        // Given
        mockContext.mockBiometryType = .faceID
        mockContext.canEvaluatePolicyResult = true
        
        // When
        let type = sut.biometricType
        
        // Then
        XCTAssertEqual(type, .faceID)
    }
    
    func test_biometricType_whenTouchID_shouldReturnTouchID() {
        // Given
        mockContext.mockBiometryType = .touchID
        mockContext.canEvaluatePolicyResult = true
        
        // When
        let type = sut.biometricType
        
        // Then
        XCTAssertEqual(type, .touchID)
    }
    
    // MARK: - Authentication Tests
    
    func test_authenticate_withSuccess_shouldReturnTrue() async throws {
        // Given
        mockContext.evaluatePolicyResult = true
        let reason = "Access your health data"
        
        // When
        let result = try await sut.authenticate(reason: reason)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockContext.lastLocalizedReason, reason)
    }
    
    func test_authenticate_withUserCancel_shouldThrowCancelled() async {
        // Given
        mockContext.evaluatePolicyResult = false
        mockContext.evaluatePolicyError = LAError(.userCancel)
        
        // When/Then
        do {
            _ = try await sut.authenticate(reason: "Test")
            XCTFail("Should throw error")
        } catch {
            XCTAssertEqual(error as? BiometricAuthError, .userCancelled)
        }
    }
    
    func test_authenticate_withBiometryLockout_shouldThrowLockout() async {
        // Given
        mockContext.evaluatePolicyResult = false
        mockContext.evaluatePolicyError = LAError(.biometryLockout)
        
        // When/Then
        do {
            _ = try await sut.authenticate(reason: "Test")
            XCTFail("Should throw error")
        } catch {
            XCTAssertEqual(error as? BiometricAuthError, .biometryLockout)
        }
    }
    
    func test_authenticate_withNotEnrolled_shouldThrowNotEnrolled() async {
        // Given
        mockContext.evaluatePolicyResult = false
        mockContext.evaluatePolicyError = LAError(.biometryNotEnrolled)
        
        // When/Then
        do {
            _ = try await sut.authenticate(reason: "Test")
            XCTFail("Should throw error")
        } catch {
            XCTAssertEqual(error as? BiometricAuthError, .biometryNotEnrolled)
        }
    }
    
    func test_authenticate_withFallback_shouldInvokeFallback() async throws {
        // Given
        mockContext.evaluatePolicyResult = false
        mockContext.evaluatePolicyError = LAError(.userFallback)
        var fallbackCalled = false
        
        // When
        let fallback: @Sendable () async -> Bool = {
            fallbackCalled = true
            return true
        }
        _ = try await sut.authenticate(reason: "Test", fallback: fallback)
        
        // Then
        XCTAssertTrue(fallbackCalled)
    }
}

// MARK: - Mock LAContext

private class MockLAContext: LAContext {
    var canEvaluatePolicyResult = true
    var canEvaluatePolicyError: Error?
    var evaluatePolicyResult = true
    var evaluatePolicyError: Error?
    var lastLocalizedReason: String?
    var mockBiometryType: LABiometryType = .none
    
    override var biometryType: LABiometryType {
        return mockBiometryType
    }
    
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if let canEvaluatePolicyError = canEvaluatePolicyError {
            error?.pointee = canEvaluatePolicyError as NSError
        }
        return canEvaluatePolicyResult
    }
    
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        lastLocalizedReason = localizedReason
        reply(evaluatePolicyResult, evaluatePolicyError)
    }
}