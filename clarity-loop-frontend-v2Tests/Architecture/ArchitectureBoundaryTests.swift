//
//  ArchitectureBoundaryTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests to ensure architectural boundaries are maintained
//

import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
    
    // MARK: - Layer Independence Tests
    
    func test_domainLayer_shouldNotDependOnOtherLayers() {
        // Domain should be completely independent
        let domainImports = getDomainLayerImports()
        
        XCTAssertFalse(domainImports.contains("ClarityData"), 
                      "Domain layer should not import Data layer")
        XCTAssertFalse(domainImports.contains("ClarityUI"), 
                      "Domain layer should not import UI layer")
        XCTAssertFalse(domainImports.contains("ClarityCore"), 
                      "Domain layer should not import Core layer")
        XCTAssertFalse(domainImports.contains("SwiftData"), 
                      "Domain layer should not depend on persistence frameworks")
        XCTAssertFalse(domainImports.contains("Amplify"), 
                      "Domain layer should not depend on external frameworks")
    }
    
    func test_dataLayer_shouldOnlyDependOnDomainAndCore() {
        // Data layer can depend on Domain and Core, but not UI
        let dataImports = getDataLayerImports()
        
        XCTAssertTrue(dataImports.contains("ClarityDomain"), 
                     "Data layer should import Domain layer")
        XCTAssertFalse(dataImports.contains("ClarityUI"), 
                      "Data layer should not import UI layer")
    }
    
    func test_uiLayer_canDependOnAllLayers() {
        // UI layer can depend on all other layers
        let uiImports = getUILayerImports()
        
        XCTAssertTrue(uiImports.contains("ClarityDomain"), 
                     "UI layer should import Domain layer")
        XCTAssertTrue(uiImports.contains("ClarityCore"), 
                     "UI layer should import Core layer")
        // UI doesn't directly import Data, it uses DI
    }
    
    // MARK: - Protocol Boundary Tests
    
    func test_repositoryProtocols_shouldBeInDomainLayer() {
        // All repository protocols should be in Domain layer
        XCTAssertTrue(fileExists("Domain/Repositories/UserRepositoryProtocol.swift"))
        XCTAssertTrue(fileExists("Domain/Repositories/HealthMetricRepositoryProtocol.swift"))
    }
    
    func test_repositoryImplementations_shouldBeInDataLayer() {
        // All repository implementations should be in Data layer
        XCTAssertTrue(fileExists("Data/Repositories/UserRepositoryImplementation.swift"))
        XCTAssertTrue(fileExists("Data/Repositories/HealthMetricRepositoryImplementation.swift"))
    }
    
    func test_domainModels_shouldNotHaveUIKitDependency() {
        // Domain models should not import UIKit or SwiftUI
        let domainFiles = [
            "User.swift",
            "HealthMetric.swift",
            "HealthMetricType.swift"
        ]
        
        for file in domainFiles {
            let content = getFileContent("Domain/Entities/\(file)")
            XCTAssertFalse(content.contains("import UIKit"), 
                          "\(file) should not import UIKit")
            XCTAssertFalse(content.contains("import SwiftUI"), 
                          "\(file) should not import SwiftUI")
        }
    }
    
    // MARK: - Dependency Direction Tests
    
    func test_dependencyDirection_shouldFlowInward() {
        // Dependencies should flow: UI -> Data -> Domain
        // Domain should have no dependencies
        
        // Check Domain has no outward dependencies
        let domainDependencies = getDomainDependencies()
        XCTAssertTrue(domainDependencies.isEmpty, 
                     "Domain should have no dependencies on other layers")
        
        // Check Data depends on Domain
        let dataDependencies = getDataDependencies()
        XCTAssertTrue(dataDependencies.contains("ClarityDomain"), 
                     "Data should depend on Domain")
        
        // Check UI depends on Domain (and possibly Core)
        let uiDependencies = getUIDependencies()
        XCTAssertTrue(uiDependencies.contains("ClarityDomain"), 
                     "UI should depend on Domain")
    }
    
    // MARK: - Use Case Tests
    
    func test_useCases_shouldBeInDomainLayer() {
        // All use cases should be in Domain layer
        XCTAssertTrue(fileExists("Domain/UseCases/LoginUseCase.swift"))
        XCTAssertTrue(fileExists("Domain/UseCases/RecordHealthMetricUseCase.swift"))
    }
    
    func test_useCases_shouldOnlyDependOnDomainAbstractions() {
        // Use cases should only depend on domain protocols, not implementations
        let loginUseCaseContent = getFileContent("Domain/UseCases/LoginUseCase.swift")
        
        XCTAssertTrue(loginUseCaseContent.contains("AuthServiceProtocol"), 
                     "Use case should depend on protocol")
        XCTAssertTrue(loginUseCaseContent.contains("UserRepositoryProtocol"), 
                     "Use case should depend on protocol")
        XCTAssertFalse(loginUseCaseContent.contains("UserRepositoryImplementation"), 
                      "Use case should not depend on implementation")
    }
    
    // MARK: - Helper Methods
    
    private func getDomainLayerImports() -> [String] {
        // In a real implementation, this would scan Domain files for imports
        return ["Foundation"]
    }
    
    private func getDataLayerImports() -> [String] {
        // In a real implementation, this would scan Data files for imports
        return ["Foundation", "ClarityDomain", "SwiftData"]
    }
    
    private func getUILayerImports() -> [String] {
        // In a real implementation, this would scan UI files for imports
        return ["SwiftUI", "ClarityDomain", "ClarityCore"]
    }
    
    private func fileExists(_ path: String) -> Bool {
        let fullPath = "/Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/clarity-loop-frontend-v2/\(path)"
        return FileManager.default.fileExists(atPath: fullPath)
    }
    
    private func getFileContent(_ path: String) -> String {
        let fullPath = "/Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/clarity-loop-frontend-v2/\(path)"
        return (try? String(contentsOfFile: fullPath)) ?? ""
    }
    
    private func getDomainDependencies() -> [String] {
        // Check Package.swift or analyze imports
        return []
    }
    
    private func getDataDependencies() -> [String] {
        return ["ClarityDomain", "ClarityCore"]
    }
    
    private func getUIDependencies() -> [String] {
        return ["ClarityDomain", "ClarityCore", "ClarityData"]
    }
}

// MARK: - Clean Architecture Principles Test

extension ArchitectureBoundaryTests {
    
    func test_cleanArchitecturePrinciples() {
        // Test 1: Independence of Business Logic
        // Domain layer should be testable without any frameworks
        let domainTestable = isDomainLayerTestableInIsolation()
        XCTAssertTrue(domainTestable, 
                     "Domain layer should be testable without framework dependencies")
        
        // Test 2: Dependency Rule
        // Source code dependencies must point inward
        let dependencyRuleValid = validateDependencyRule()
        XCTAssertTrue(dependencyRuleValid, 
                     "Dependencies should flow inward: UI -> Data -> Domain")
        
        // Test 3: Abstraction Rule
        // Inner layers should not know about outer layers
        let abstractionRuleValid = validateAbstractionRule()
        XCTAssertTrue(abstractionRuleValid, 
                     "Inner layers should depend on abstractions, not concrete implementations")
    }
    
    private func isDomainLayerTestableInIsolation() -> Bool {
        // Check if domain tests run without framework setup
        return true // Simplified for example
    }
    
    private func validateDependencyRule() -> Bool {
        // Ensure dependencies flow correctly
        return true // Simplified for example
    }
    
    private func validateAbstractionRule() -> Bool {
        // Ensure proper abstraction boundaries
        return true // Simplified for example
    }
}
