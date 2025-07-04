# CLARITY Configuration Guide

## Overview

This guide centralizes all configuration values for the CLARITY Pulse V2 application. Use this as the single source of truth for all environment-specific settings.

## Production Configuration

### API Configuration
```swift
struct ProductionConfig {
    static let apiBaseURL = URL(string: "https://clarity.novamindnyc.com")!
    static let apiVersion = "/api/v1"
    static let websocketURL = URL(string: "wss://clarity.novamindnyc.com/ws")!
}
```

### AWS Cognito Configuration
```swift
struct CognitoConfig {
    static let region = "us-east-1"
    static let userPoolId = "us-east-1_efXaR5EcP"
    static let clientId = "7sm7ckrkovg78b03n1595euc71"
    static let identityPoolId = "" // Not currently used
}
```

### AWS Services Configuration
```swift
struct AWSConfig {
    static let region = "us-east-1"
    static let s3BucketName = "clarity-health-uploads"
    static let dynamoDBTableName = "clarity-health-data"
}
```

## Environment Management

### Development Environment
```swift
#if DEBUG
struct DevelopmentConfig {
    static let apiBaseURL = URL(string: "http://localhost:8000")!
    static let mockAuthEnabled = true
    static let skipSSLValidation = true // Only for local development
}
#endif
```

### Testing Environment
```swift
struct TestConfig {
    static let apiBaseURL = URL(string: "https://api.test.com")! // Mock URL for tests
    static let useMockServices = true
    static let cognitoPoolId = "mock-pool-id"
    static let cognitoClientId = "mock-client-id"
}
```

## Feature Flags

```swift
struct FeatureFlags {
    static let biometricAuthEnabled = true
    static let offlineSyncEnabled = true
    static let advancedInsightsEnabled = false // Coming soon
    static let appleWatchSyncEnabled = false // Coming soon
    static let pushNotificationsEnabled = false // Coming soon
}
```

## Security Configuration

### Certificate Pinning
```swift
struct SecurityConfig {
    static let certificatePins = [
        "clarity.novamindnyc.com": "SHA256:XXXXXX" // Add actual certificate hash
    ]
    static let minimumTLSVersion = "1.3"
    static let allowSelfSignedCertificates = false
}
```

### HIPAA Compliance Settings
```swift
struct HIPAAConfig {
    static let encryptionRequired = true
    static let auditLoggingEnabled = true
    static let sessionTimeout = 15 * 60 // 15 minutes
    static let maxLoginAttempts = 5
    static let accountLockoutDuration = 30 * 60 // 30 minutes
}
```

## API Endpoints Reference

All endpoints are relative to the base URL: `https://clarity.novamindnyc.com/api/v1`

### Authentication
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `POST /auth/refresh`
- `POST /auth/verify-email`
- `POST /auth/forgot-password`
- `POST /auth/reset-password`

### Health Data
- `GET /health/metrics`
- `POST /health/metrics`
- `POST /health/sync`
- `GET /health/summary`

### User Management
- `GET /user/profile`
- `PUT /user/profile`
- `DELETE /user/account`

## Configuration Loading

### Info.plist Configuration
Add these to your Info.plist:
```xml
<key>API_BASE_URL</key>
<string>https://clarity.novamindnyc.com</string>
<key>AWS_REGION</key>
<string>us-east-1</string>
```

### Environment Variables (Build Time)
```bash
# Production build
API_ENVIRONMENT=production
COGNITO_USER_POOL_ID=us-east-1_efXaR5EcP
COGNITO_CLIENT_ID=7sm7ckrkovg78b03n1595euc71

# Development build
API_ENVIRONMENT=development
ENABLE_MOCK_SERVICES=true
```

## Amplify Configuration File

The `amplifyconfiguration.json` file in the project root contains:
```json
{
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-east-1_efXaR5EcP",
                        "AppClientId": "7sm7ckrkovg78b03n1595euc71",
                        "Region": "us-east-1"
                    }
                }
            }
        }
    },
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "clarityAPI": {
                    "endpointType": "REST",
                    "endpoint": "https://clarity.novamindnyc.com",
                    "region": "us-east-1",
                    "authorizationType": "AMAZON_COGNITO_USER_POOLS"
                }
            }
        }
    }
}
```

## Usage in Code

```swift
// Access configuration
let apiURL = ProductionConfig.apiBaseURL.appendingPathComponent(ProductionConfig.apiVersion)
let authEnabled = !TestConfig.useMockServices

// Check feature flags
if FeatureFlags.biometricAuthEnabled {
    // Enable biometric authentication
}

// Environment-specific logic
#if DEBUG
    let baseURL = DevelopmentConfig.apiBaseURL
#else
    let baseURL = ProductionConfig.apiBaseURL
#endif
```

## Important Notes

1. **Never commit sensitive values**: Use environment variables or secure key storage
2. **Certificate pins**: Must be updated when backend certificates change
3. **Feature flags**: Can be overridden by backend configuration
4. **Mock services**: Only available in DEBUG builds
5. **Production values**: Always use HTTPS in production

## Validation Checklist

- [ ] API base URL is HTTPS
- [ ] Cognito configuration matches AWS Console
- [ ] Certificate pins are current
- [ ] Feature flags match product requirements
- [ ] Security settings comply with HIPAA
- [ ] Environment separation is maintained