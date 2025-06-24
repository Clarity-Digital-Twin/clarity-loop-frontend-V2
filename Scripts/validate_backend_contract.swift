#!/usr/bin/env swift

import Foundation

// MARK: - Contract Validation Script

// This script validates that frontend DTOs match backend API expectations
// Run this in CI/CD to catch contract mismatches early

let backendURL = "https://clarity.novamindnyc.com"

// MARK: - Validation Results

struct ValidationResult {
    let endpoint: String
    let method: String
    let passed: Bool
    let error: String?
}

var results: [ValidationResult] = []

// MARK: - Helper Functions

func validateEndpoint(
    endpoint: String,
    method: String,
    headers: [String: String] = [:],
    body: Data? = nil,
    expectedStatus: Int,
    validator: (Data) -> Bool
) async {
    guard let url = URL(string: "\(backendURL)\(endpoint)") else {
        results.append(ValidationResult(
            endpoint: endpoint,
            method: method,
            passed: false,
            error: "Invalid URL"
        ))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    request.httpBody = body

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        if httpResponse.statusCode == expectedStatus, validator(data) {
            results.append(ValidationResult(
                endpoint: endpoint,
                method: method,
                passed: true,
                error: nil
            ))
        } else {
            results.append(ValidationResult(
                endpoint: endpoint,
                method: method,
                passed: false,
                error: "Status: \(httpResponse.statusCode), Expected: \(expectedStatus)"
            ))
        }
    } catch {
        results.append(ValidationResult(
            endpoint: endpoint,
            method: method,
            passed: false,
            error: error.localizedDescription
        ))
    }
}

// MARK: - Contract Validators

func validateHealthResponse(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return false
    }

    // Validate expected fields
    return json["status"] != nil &&
        json["service"] != nil &&
        json["version"] != nil
}

func validateAuthHealthResponse(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return false
    }

    // Validate expected fields
    return json["status"] as? String == "healthy" &&
        json["service"] as? String == "authentication" &&
        json["version"] != nil
}

func validateTokenResponse(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return false
    }

    // Validate expected fields
    return json["access_token"] != nil &&
        json["refresh_token"] != nil &&
        json["token_type"] != nil &&
        json["expires_in"] != nil &&
        json["scope"] != nil
}

func validateProblemDetail(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return false
    }

    // Validate problem detail format
    return json["type"] != nil &&
        json["title"] != nil &&
        json["detail"] != nil &&
        json["status"] != nil
}

// MARK: - Main Validation

print("🔍 CLARITY Backend Contract Validation")
print("=====================================")
print("Backend URL: \(backendURL)")
print("")

// Create async context
Task {
    // Test 1: Health Check
    print("1️⃣ Validating /health endpoint...")
    await validateEndpoint(
        endpoint: "/health",
        method: "GET",
        expectedStatus: 200,
        validator: validateHealthResponse
    )

    // Test 2: Auth Health
    print("2️⃣ Validating /api/v1/auth/health endpoint...")
    await validateEndpoint(
        endpoint: "/api/v1/auth/health",
        method: "GET",
        expectedStatus: 200,
        validator: validateAuthHealthResponse
    )

    // Test 3: Registration with invalid data (to test error format)
    print("3️⃣ Validating registration error format...")
    let invalidRegistration = """
    {
        "email": "invalid-email",
        "password": "short",
        "display_name": "Test"
    }
    """.data(using: .utf8)!

    await validateEndpoint(
        endpoint: "/api/v1/auth/register",
        method: "POST",
        body: invalidRegistration,
        expectedStatus: 422,
        validator: { _ in true } // Accept any validation error
    )

    // Test 4: Login with invalid credentials (to test error format)
    print("4️⃣ Validating login error format...")
    let invalidLogin = """
    {
        "email": "nonexistent@test.com",
        "password": "wrongpassword"
    }
    """.data(using: .utf8)!

    await validateEndpoint(
        endpoint: "/api/v1/auth/login",
        method: "POST",
        body: invalidLogin,
        expectedStatus: 401,
        validator: validateProblemDetail
    )

    // Test 5: Unauthorized access (to test auth error format)
    print("5️⃣ Validating unauthorized error format...")
    await validateEndpoint(
        endpoint: "/api/v1/auth/me",
        method: "GET",
        headers: ["Authorization": "Bearer invalid_token"],
        expectedStatus: 401,
        validator: validateProblemDetail
    )

    // Print Results
    print("\n📊 Validation Results")
    print("====================")

    var passed = 0
    var failed = 0

    for result in results {
        let status = result.passed ? "✅" : "❌"
        print("\(status) \(result.method) \(result.endpoint)")
        if let error = result.error {
            print("   Error: \(error)")
        }

        if result.passed {
            passed += 1
        } else {
            failed += 1
        }
    }

    print("\nSummary: \(passed) passed, \(failed) failed")

    // Exit with appropriate code
    exit(failed > 0 ? 1 : 0)
}

// Keep script running until async tasks complete
RunLoop.main.run()
