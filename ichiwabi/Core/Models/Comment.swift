import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Comment {
    // Core properties
    @Attribute(.unique) var id: String            // Firestore document ID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String
    var lastSyncedAt: Date?
    
    // Relationships
    var user: User?          // Who wrote the comment
    var response: VideoResponse?  // Which video this comments on
    var parentComment: Comment?   // For threaded comments
    @Relationship(deleteRule: .cascade) var replies: [Comment]
    
    // Engagement metrics
    var likeCount: Int
    var isEdited: Bool
    
    init(id: String,
         text: String,
         user: User?,
         response: VideoResponse?,
         parentComment: Comment? = nil) {
        self.id = id
        self.text = text
        self.user = user
        self.response = response
        self.parentComment = parentComment
        self.likeCount = 0
        self.isEdited = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = SyncStatus.synced.rawValue
        self.replies = []
    }
}

// MARK: - SyncableModel Conformance
extension Comment: SyncableModel {
    static var collectionPath: String { "comments" }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Comment {
        guard let text = data["text"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let likeCount = data["likeCount"] as? Int,
              let isEdited = data["isEdited"] as? Bool else {
            throw SyncError.invalidData("Missing required fields in Comment Firestore data")
        }
        
        let comment = Comment(id: id,
                            text: text,
                            user: nil,  // Relationships will be populated by sync service
                            response: nil)
        
        comment.createdAt = createdAtTimestamp.dateValue()
        comment.updatedAt = updatedAtTimestamp.dateValue()
        comment.likeCount = likeCount
        comment.isEdited = isEdited
        comment.syncStatus = data["syncStatus"] as? String ?? SyncStatus.synced.rawValue
        
        if let lastSyncedAtTimestamp = data["lastSyncedAt"] as? Timestamp {
            comment.lastSyncedAt = lastSyncedAtTimestamp.dateValue()
        }
        
        return comment
    }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "text": text,
            "likeCount": likeCount,
            "isEdited": isEdited,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "syncStatus": syncStatus
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        
        if let user = user {
            data["userId"] = user.id
        }
        
        if let response = response {
            data["responseId"] = response.id
        }
        
        if let parentComment = parentComment {
            data["parentCommentId"] = parentComment.id
        }
        
        return data
    }
    
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Comment ID cannot be empty")
        }
        if text.isEmpty {
            throw SyncError.invalidData("Comment text cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: Comment) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: Comment) throws -> Comment {
        if other.updatedAt > self.updatedAt {
            self.text = other.text
            self.likeCount = other.likeCount
            self.isEdited = other.isEdited
            self.user = other.user
            self.response = other.response
            self.parentComment = other.parentComment
        }
        
        self.syncStatus = SyncStatus.pendingUpload.rawValue
        self.lastSyncedAt = Date()
        self.updatedAt = Date()
        
        return self
    }
} 