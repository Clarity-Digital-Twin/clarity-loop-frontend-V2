//
//  SwiftUIEnvironmentDITests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD Tests for SwiftUI Environment-based Dependency Injection
//

import XCTest
import SwiftUI
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

final class SwiftUIEnvironmentDITests: XCTestCase {
    
    // MARK: - Test Protocols
    
    protocol TestServiceProtocol {
        var value: String { get }
    }
    
    struct TestService: TestServiceProtocol {
        let value: String
    }
    
    protocol TestRepositoryProtocol {
        func fetch() -> String
    }
    
    struct TestRepository: TestRepositoryProtocol {
        let service: TestServiceProtocol
        
        func fetch() -> String {
            "Data from \(service.value)"
        }
    }
    
    // MARK: - Environment Key Tests
    
    func test_environmentKey_shouldStoreAndRetrieveService() {
        // Given
        struct TestServiceKey: EnvironmentKey {
            static let defaultValue: TestServiceProtocol? = nil
        }
        
        // When
        var environment = EnvironmentValues()
        let service = TestService(value: "test")
        environment[TestServiceKey.self] = service
        
        // Then
        XCTAssertNotNil(environment[TestServiceKey.self])
        XCTAssertEqual(environment[TestServiceKey.self]?.value, "test")
    }
    
    func test_environmentValues_extension_shouldProvideTypeSafeAccess() {
        // Given
        let service = TestService(value: "injected")
        
        // When
        var environment = EnvironmentValues()
        environment.testService = service
        
        // Then
        XCTAssertNotNil(environment.testService)
        XCTAssertEqual(environment.testService?.value, "injected")
    }
    
    // MARK: - Dependencies Container Tests
    
    func test_dependencies_shouldRegisterAndResolveServices() {
        // Given
        let dependencies = Dependencies()
        let service = TestService(value: "registered")
        
        // When
        dependencies.register(TestServiceProtocol.self, instance: service)
        let resolved = dependencies.resolve(TestServiceProtocol.self)
        
        // Then
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.value, "registered")
    }
    
    func test_dependencies_shouldSupportFactoryRegistration() {
        // Given
        let dependencies = Dependencies()
        var factoryCalled = false
        
        // When
        dependencies.register(TestServiceProtocol.self) {
            factoryCalled = true
            return TestService(value: "factory created")
        }
        
        let resolved = dependencies.resolve(TestServiceProtocol.self)
        
        // Then
        XCTAssertTrue(factoryCalled)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.value, "factory created")
    }
    
    func test_dependencies_shouldSupportDependencyChaining() {
        // Given
        let dependencies = Dependencies()
        
        // When
        dependencies.register(TestServiceProtocol.self) {
            TestService(value: "base service")
        }
        
        dependencies.register(TestRepositoryProtocol.self) { container in
            let service = container.resolve(TestServiceProtocol.self)!
            return TestRepository(service: service)
        }
        
        let repository = dependencies.resolve(TestRepositoryProtocol.self)
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertEqual(repository?.fetch(), "Data from base service")
    }
    
    // MARK: - SwiftUI Integration Tests
    
    func test_view_shouldAccessDependenciesViaEnvironment() {
        // Given
        struct TestView: View {
            @Environment(\.testService) var service
            
            var body: some View {
                Text(service?.value ?? "no service")
            }
        }
        
        let service = TestService(value: "environment service")
        let dependencies = Dependencies()
        dependencies.register(TestServiceProtocol.self, instance: service)
        
        // When
        let view = TestView()
            .dependencies(dependencies)
        
        // Then
        // This would be tested with ViewInspector or similar
        // For now, we're testing the setup compiles correctly
        XCTAssertNotNil(view)
    }
    
    func test_viewModel_shouldReceiveDependenciesFromEnvironment() {
        // Given
        @Observable
        final class TestViewModel {
            let service: TestServiceProtocol
            
            init(service: TestServiceProtocol) {
                self.service = service
            }
            
            func getValue() -> String {
                service.value
            }
        }
        
        struct TestView: View {
            @Environment(\.dependencies) var dependencies
            @State private var viewModel: TestViewModel?
            
            var body: some View {
                Text(viewModel?.getValue() ?? "no value")
                    .onAppear {
                        if let service = dependencies.resolve(TestServiceProtocol.self) {
                            viewModel = TestViewModel(service: service)
                        }
                    }
            }
        }
        
        // When
        let service = TestService(value: "view model service")
        let dependencies = Dependencies()
        dependencies.register(TestServiceProtocol.self, instance: service)
        
        let view = TestView()
            .environment(\.dependencies, dependencies)
        
        // Then
        XCTAssertNotNil(view)
    }
    
    // MARK: - Mock Support Tests
    
    func test_dependencies_shouldSupportMockingForTests() {
        // Given
        struct MockService: TestServiceProtocol {
            let value: String = "mock value"
        }
        
        let dependencies = Dependencies.mock { container in
            container.register(TestServiceProtocol.self, instance: MockService())
        }
        
        // When
        let service = dependencies.resolve(TestServiceProtocol.self)
        
        // Then
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.value, "mock value")
    }
    
    // MARK: - Thread Safety Tests
    
    func test_dependencies_shouldBeThreadSafe() async {
        // Given
        let dependencies = Dependencies()
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let service = TestService(value: "service \(i)")
                    dependencies.register(TestServiceProtocol.self, instance: service)
                    _ = dependencies.resolve(TestServiceProtocol.self)
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - App Integration Tests
    
    func test_appDependencies_shouldConfigureAllRequiredServices() {
        // Given
        let dependencies = Dependencies()
        let configurator = AppDependencyConfigurator()
        
        // When
        configurator.configure(dependencies)
        
        // Then
        XCTAssertNotNil(dependencies.resolve(AuthServiceProtocol.self))
        XCTAssertNotNil(dependencies.resolve(UserRepositoryProtocol.self))
        XCTAssertNotNil(dependencies.resolve(HealthMetricRepositoryProtocol.self))
    }
    
    func test_appView_shouldInjectDependenciesIntoEnvironment() {
        // Given
        struct TestApp: App {
            let dependencies = Dependencies()
            
            var body: some Scene {
                WindowGroup {
                    ContentView()
                        .dependencies(dependencies)
                }
            }
        }
        
        // When
        let app = TestApp()
        
        // Then
        XCTAssertNotNil(app.dependencies)
    }
}

// MARK: - Test Environment Extensions

private extension EnvironmentValues {
    var testService: SwiftUIEnvironmentDITests.TestServiceProtocol? {
        get { self[TestServiceKey.self] }
        set { self[TestServiceKey.self] = newValue }
    }
}

private struct TestServiceKey: EnvironmentKey {
    static let defaultValue: SwiftUIEnvironmentDITests.TestServiceProtocol? = nil
}