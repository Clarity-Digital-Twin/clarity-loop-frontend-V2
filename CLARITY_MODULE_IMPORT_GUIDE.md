# CLARITY Module Import Guide

## Why This Guide Exists

Early in a modular Swift project, module import errors are the #1 compilation issue. This guide prevents the "cannot find module" and "type does not conform to protocol" errors that plague Greenfield projects.

## Module Structure

```
ClarityPulse (Package)
├── ClarityCore (Library Target)
├── ClarityDomain (Library Target) 
├── ClarityData (Library Target)
├── ClarityUI (Library Target)
└── Test Targets
```

## Critical Understanding

**Each target is a separate module!** When you split code into targets:
- They compile independently
- They can't see each other's internals
- Cross-module access requires `public` visibility

## What Goes Where

### ClarityDomain
- **Contains**: Entities, Use Cases, Repository Protocols, Service Protocols
- **Depends on**: ClarityCore
- **Public Types**: All entities, protocols, and use cases

### ClarityData  
- **Contains**: Repository Implementations, DTOs, API Clients
- **Depends on**: ClarityDomain, ClarityCore, Amplify
- **Public Types**: None! (implementations stay internal)

### ClarityUI
- **Contains**: SwiftUI Views, ViewModels
- **Depends on**: ClarityDomain, ClarityData, ClarityCore  
- **Public Types**: Only if shared between features

## Visibility Checklist

### MUST be public in Domain layer:
```swift
// Entities
public struct HealthMetric { }
public final class User { }
public enum HealthMetricType { }

// Protocols  
public protocol UserRepositoryProtocol { }
public protocol AuthServiceProtocol { }

// Use Cases
public final class LoginUseCase { }
public final class RecordHealthMetricUseCase { }

// Errors
public enum ValidationError { }
public enum RepositoryError { }
```

### STAYS internal in Data layer:
```swift
// Implementations
final class UserRepositoryImplementation { } // internal
final class APIClient { }                    // internal

// DTOs (only used within Data layer)
struct UserDTO { }                           // internal
struct HealthMetricDTO { }                   // internal
```

## Import Patterns

### Test Files

```swift
// Testing Domain layer
import XCTest
@testable import ClarityDomain

// Testing Data layer (needs domain types)
import XCTest
@testable import ClarityData
@testable import ClarityDomain

// Testing UI layer
import XCTest
@testable import ClarityUI
import ClarityDomain  // For public types
```

### Production Code

```swift
// In Data layer files
import Foundation
import ClarityDomain  // For protocols to implement

// In UI layer files  
import SwiftUI
import ClarityDomain  // For entities and use cases
import ClarityData    // Usually not needed directly
```

## Common Errors and Fixes

### Error: "No such module 'clarity_loop_frontend_v2'"
**Fix**: Import the actual module names (ClarityDomain, ClarityData, etc.)

### Error: "Cannot find type 'User' in scope"
**Fix**: 
1. Import the module containing the type
2. Ensure the type is `public`

### Error: "Type does not conform to protocol"
**Fix**:
1. Make sure all protocol requirements are implemented
2. Check method signatures match exactly (including labels)
3. Ensure types referenced in signatures are imported

### Error: "Generic parameter 'T' could not be inferred"
**Fix**: Update method calls to match new signatures (e.g., `delete(type:id:)`)

## Quick Reference

```bash
# See all module names
swift package dump-package | jq '.targets[].name'

# Verify imports compile
swift build --target ClarityDomain
swift build --target ClarityData
swift test
```

## Prevention Strategies

1. **Always check module membership** when creating files
2. **Make types public immediately** if they cross boundaries
3. **Run tests early and often** to catch import issues
4. **Use code completion** - it only suggests valid modules

## Remember

- This is an APP, not a framework - only make public what crosses module boundaries
- Test targets can see internals with `@testable import`
- The app executable (clarity-loop-frontend-v2) is NOT an importable module
- When in doubt, check what module owns the type you need

---

Follow this guide and you'll avoid 90% of early project compilation issues!