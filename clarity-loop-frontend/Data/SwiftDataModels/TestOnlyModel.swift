import Foundation
import SwiftData

/// A minimal model used only for test environments
/// This ensures we can create a ModelContainer even when other models aren't available
@Model
final class TestOnlyModel {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    
    init() {}
}