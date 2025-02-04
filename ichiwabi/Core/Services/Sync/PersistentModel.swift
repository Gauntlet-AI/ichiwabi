import Foundation
import SwiftData

/// Protocol for models that can be persisted in SwiftData
public protocol LocalPersistentModel {
    /// The unique identifier for the model
    var id: String { get }
    
    /// The timestamp when the model was last modified
    var updatedAt: Date { get set }
} 