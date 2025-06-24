# Test Fixing Patterns - CLARITY iOS

## Common Patterns for Fixing Placeholder Tests

### Pattern 1: XCTSkip to Real Assertion

**Before:**
```swift
func testSomething() {
    XCTSkip("Placeholder test - needs implementation")
}
```

**After:**
```swift
func testSomething() async throws {
    // Arrange
    let expected = "value"
    
    // Act
    let result = await viewModel.doSomething()
    
    // Assert
    XCTAssertEqual(result, expected)
}
```

### Pattern 2: Creating Missing Mocks

**Problem:** Repository/Service is final class or missing protocol

**Solution:**
```swift
// 1. Create protocol if missing
protocol SomeRepositoryProtocol {
    func fetch() async throws -> [Model]
}

// 2. Create mock
@MainActor
final class MockSomeRepository: ObservableBaseRepository<Model>, SomeRepositoryProtocol {
    var shouldFail = false
    var mockData: [Model] = []
    var fetchCalled = false
    
    func fetch() async throws -> [Model] {
        fetchCalled = true
        if shouldFail {
            throw RepositoryError.entityNotFound
        }
        return mockData
    }
}
```

### Pattern 3: Final Class Workaround

**Problem:** ViewModel is final and can't be mocked

**Solution:** Create testable wrapper
```swift
@MainActor
final class TestableSomeViewModel: BaseViewModel {
    private let repository: any SomeRepositoryProtocol
    
    init(modelContext: ModelContext, repository: any SomeRepositoryProtocol) {
        self.repository = repository
        super.init(modelContext: modelContext)
    }
    
    // Mirror all public methods from original ViewModel
}
```

### Pattern 4: Async Test Pattern

**Standard Pattern:**
```swift
func testAsyncOperation() async throws {
    // Arrange
    mockRepository.mockData = [TestData]
    
    // Act
    await viewModel.loadData()
    
    // Assert
    switch viewModel.state {
    case .loaded(let data):
        XCTAssertEqual(data.count, 1)
    case .error:
        XCTFail("Should not error")
    default:
        XCTFail("Unexpected state")
    }
}
```

### Pattern 5: Error Testing

```swift
func testErrorHandling() async throws {
    // Arrange
    mockRepository.shouldFail = true
    mockRepository.mockError = APIError.unauthorized
    
    // Act
    await viewModel.performAction()
    
    // Assert
    switch viewModel.state {
    case .error(let error):
        XCTAssertTrue(error is APIError)
    default:
        XCTFail("Expected error state")
    }
}
```

## Common Issues and Solutions

### Issue 1: "Cannot find type in scope"
**Solution:** Check imports, create missing types, or create mocks

### Issue 2: "Value of type X has no member Y"
**Solution:** Add missing method to mock or protocol

### Issue 3: "Cannot assign to property"
**Solution:** Make property mutable in mock

### Issue 4: Test compiles but fails
**Solution:** Check mock behavior, ensure proper setup in arrange phase

## Mock Creation Checklist

- [ ] Create protocol for dependencies
- [ ] Add behavior tracking (methodCalled flags)
- [ ] Add controllable failure (shouldFail)
- [ ] Add mock data properties
- [ ] Add captured parameter properties
- [ ] Implement all protocol methods
- [ ] Add reset() method for test cleanup

## Test Structure Template

```swift
func testDescriptiveName() async throws {
    // Arrange
    // - Set up mocks
    // - Configure expected behavior
    // - Prepare test data
    
    // Act
    // - Call the method being tested
    // - Capture results
    
    // Assert
    // - Verify behavior (methods called)
    // - Check state changes
    // - Validate results
}
```

## Priority Order for Fixing Tests

1. **ViewModels** - Core business logic
2. **Repositories** - Data layer
3. **Services** - Infrastructure
4. **Integration** - End-to-end flows
5. **UI Tests** - Visual components

## Red Flags to Watch For

1. Tests that pass without assertions
2. Tests that never fail when they should
3. Mocks that don't track behavior
4. Missing error case tests
5. No async handling tests

Remember: A test that can't fail is not a test!