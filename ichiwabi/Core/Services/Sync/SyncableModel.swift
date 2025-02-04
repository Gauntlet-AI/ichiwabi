import Foundation
import FirebaseFirestore

public protocol SyncableModel {
    /// The sync status of the model
    var syncStatus: String { get set }
    
    /// The timestamp when the model was last synced
    var lastSyncedAt: Date? { get set }
    
    /// The collection path in Firestore where this model is stored
    static var collectionPath: String { get }
    
    /// Convert the model to a Firestore document
    func toFirestoreData() throws -> [String: Any]
    
    /// Create a model instance from Firestore data
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Self
    
    /// Validate the model before syncing
    func validate() throws
    
    /// Compare with another instance to detect conflicts
    func hasConflictsWith(_ other: Self) -> Bool
    
    /// Merge changes from another instance in case of conflict
    func mergeChanges(from other: Self) throws -> Self
} 