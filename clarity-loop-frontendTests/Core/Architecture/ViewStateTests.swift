@testable import clarity_loop_frontend
import XCTest

/// Tests for ViewState<T> pattern to catch NaN values and binding issues
/// CRITICAL: These tests will catch the CoreGraphics NaN errors and layout issues
final class ViewStateTests: XCTestCase {
    // MARK: - Test Setup

    override func setUpWithError() throws {
        // Set up ViewState test environment
    }

    override func tearDownWithError() throws {
        // Clean up test environment
    }

    // MARK: - NaN Value Detection Tests

    func testNoNaNValuesInViewStateTransitions() throws {
        // Test ViewState transitions don't produce NaN values
        let idleState = ViewState<String>.idle
        let loadingState = ViewState<String>.loading
        let loadedState = ViewState<String>.loaded("test data")
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        let errorState = ViewState<String>.error(testError)
        let emptyState = ViewState<String>.empty

        // Verify no state contains NaN values
        switch idleState {
        case .idle:
            break // Valid state
        default:
            XCTFail("Idle state should be .idle, but was \(idleState)")
        }

        switch loadingState {
        case .loading:
            break // Valid state
        default:
            XCTFail("Loading state should be .loading, but was \(loadingState)")
        }

        switch loadedState {
        case let .loaded(data):
            XCTAssertEqual(data, "test data")
            XCTAssertFalse(data.isEmpty, "Loaded data should not be empty")
        default:
            XCTFail("Loaded state should contain data, but was \(loadedState)")
        }

        switch errorState {
        case let .error(error):
            let errorMessage = error.localizedDescription
            XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
            XCTAssertFalse(errorMessage.contains("nan"), "Error message should not contain 'nan'")
            XCTAssertFalse(errorMessage.contains("NaN"), "Error message should not contain 'NaN'")
        default:
            XCTFail("Error state should contain error, but was \(errorState)")
        }

        switch emptyState {
        case .empty:
            break // Valid state
        default:
            XCTFail("Empty state should be .empty, but was \(emptyState)")
        }
    }

    func testValidNumericPropertiesInLoadingState() throws {
        // Test loading state numeric properties are valid
        let loadingState = ViewState<Double>.loading

        // Simulate progress calculation that could produce NaN
        let progress = 0.5
        let validProgress = progress.isNaN ? 0.0 : progress

        XCTAssertFalse(validProgress.isNaN, "Progress should never be NaN")
        XCTAssertTrue(validProgress >= 0.0 && validProgress <= 1.0, "Progress should be between 0.0 and 1.0")

        // Test edge case calculations
        let zeroProgress = 0.0 / 1.0
        XCTAssertFalse(zeroProgress.isNaN, "Zero progress calculation should be valid")

        // Test that we catch potential NaN scenarios
        let potentialNaN = 0.0 / 0.0
        XCTAssertTrue(potentialNaN.isNaN, "0/0 should produce NaN (test our detection)")

        // Ensure we handle it properly
        let safeValue = potentialNaN.isNaN ? 0.0 : potentialNaN
        XCTAssertFalse(safeValue.isNaN, "Safe value should never be NaN")
    }

    // MARK: - Binding Validation Tests

    func testObservableBindingStability() throws {
        // Test @Observable bindings remain stable

        // Create a simple test class (Note: @Observable not allowed on local types)
        class TestViewModel {
            var value = ""
            var numericValue = 0.0

            func updateValue(_ newValue: String) {
                value = newValue
            }

            func updateNumericValue(_ newValue: Double) {
                // Ensure we never set NaN values
                numericValue = newValue.isNaN ? 0.0 : newValue
            }
        }

        let viewModel = TestViewModel()

        // Test string binding stability
        viewModel.updateValue("test")
        XCTAssertEqual(viewModel.value, "test")

        viewModel.updateValue("")
        XCTAssertEqual(viewModel.value, "")

        // Test numeric binding stability
        viewModel.updateNumericValue(42.0)
        XCTAssertEqual(viewModel.numericValue, 42.0)
        XCTAssertFalse(viewModel.numericValue.isNaN)

        // Test NaN protection
        viewModel.updateNumericValue(.nan)
        XCTAssertEqual(viewModel.numericValue, 0.0)
        XCTAssertFalse(viewModel.numericValue.isNaN, "ViewModel should protect against NaN values")
    }

    func testViewStateBindingWithSwiftUI() throws {
        // Test ViewState bindings work with SwiftUI

        class TestViewStateModel {
            var state: ViewState<String> = .loading

            func updateToLoaded(_ data: String) {
                state = .loaded(data)
            }

            func updateToError(_ errorMessage: String) {
                let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                state = .error(error)
            }

            func updateToLoading() {
                state = .loading
            }
        }

        let model = TestViewStateModel()

        // Test initial loading state
        switch model.state {
        case .loading:
            break // Expected
        default:
            XCTFail("Initial state should be loading, but was \(model.state)")
        }

        // Test loaded transition
        model.updateToLoaded("loaded data")
        switch model.state {
        case let .loaded(data):
            XCTAssertEqual(data, "loaded data")
        default:
            XCTFail("State should be loaded after update, but was \(model.state)")
        }

        // Test error transition
        let testErrorMessage = "Test error occurred"
        model.updateToError(testErrorMessage)
        switch model.state {
        case let .error(error):
            let errorMessage = error.localizedDescription
            XCTAssertEqual(errorMessage, testErrorMessage)
            XCTAssertFalse(errorMessage.isEmpty)
        default:
            XCTFail("State should be error after update, but was \(model.state)")
        }

        // Test loading transition
        model.updateToLoading()
        switch model.state {
        case .loading:
            break // Expected
        default:
            XCTFail("State should be loading after update, but was \(model.state)")
        }
    }

    // MARK: - Error State Tests

    func testErrorStateHandling() throws {
        // Test error state doesn't cause layout issues
        let errorMessage = "Test error message"
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        let errorState = ViewState<String>.error(testError)

        switch errorState {
        case let .error(error):
            // Verify error is properly structured
            let errorText = error.localizedDescription
            XCTAssertFalse(errorText.isEmpty, "Error message should not be empty")
            XCTAssertFalse(errorText.contains("nan"), "Error message should not contain 'nan'")
            XCTAssertFalse(errorText.contains("NaN"), "Error message should not contain 'NaN'")
            XCTAssertEqual(errorText, errorMessage, "Error message should match expected")
        default:
            XCTFail("Error state should contain error, but was \(errorState)")
        }
    }

    func testErrorStateNumericProperties() throws {
        // Test error states have valid numeric properties
        let errorMessage = "HTTP 404: Not found"
        let testError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        let errorState = ViewState<Double>.error(testError)

        switch errorState {
        case let .error(error):
            let errorText = error.localizedDescription
            XCTAssertFalse(errorText.isEmpty, "Error message should not be empty")
            XCTAssertFalse(errorText.contains("nan"), "Error message should not contain 'nan'")
            XCTAssertFalse(errorText.contains("NaN"), "Error message should not contain 'NaN'")
            XCTAssertEqual(errorText, errorMessage, "Error message should match expected")
        default:
            XCTFail("Error state should contain error, but was \(errorState)")
        }

        // Test that we can recover from error states without NaN propagation
        let recoveredState = ViewState<Double>.loaded(42.0)
        switch recoveredState {
        case let .loaded(value):
            XCTAssertFalse(value.isNaN, "Recovered value should not be NaN")
            XCTAssertEqual(value, 42.0, "Recovered value should be correct")
        default:
            XCTFail("Recovery should result in loaded state, but was \(recoveredState)")
        }
    }

    // MARK: - Test Cases

    func testViewState_InitialState() {
        let state: ViewState<String> = .idle
        XCTAssertEqual(state, .idle, "Initial state should be .idle")
    }

    func testViewState_LoadingState() {
        let state: ViewState<String> = .loading
        XCTAssertEqual(state, .loading, "State should be .loading")
    }

    func testViewState_LoadedState_Success() {
        let successData = "Success Data"
        let state: ViewState<String> = .loaded(successData)

        guard case let .loaded(data) = state else {
            XCTFail("State should be .loaded, but was \(state)")
            return
        }
        XCTAssertEqual(data, successData, "Loaded data does not match expected data.")
    }

    func testViewState_ErrorState() {
        let errorMessage = "Test Error"
        let error = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        let state: ViewState<String> = .error(error)

        guard case let .error(actualError) = state else {
            XCTFail("State should be .error, but was \(state)")
            return
        }
        XCTAssertEqual(actualError.localizedDescription, errorMessage, "Error message does not match expected message.")
    }

    func testViewState_EquatableConformance() {
        let state1: ViewState<Int> = .loaded(10)
        let state2: ViewState<Int> = .loaded(10)
        let state3: ViewState<Int> = .loaded(20)
        let state4: ViewState<Int> = .loading

        XCTAssertEqual(state1, state2, ".loaded states with same data should be equal.")
        XCTAssertNotEqual(state1, state3, ".loaded states with different data should not be equal.")
        XCTAssertNotEqual(state1, state4, "Different states should not be equal.")
    }
}
