import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Notification: SyncableModel {
    // Core properties
    var id: String            // Firestore document ID
    var type: NotificationType
    var createdAt: Date
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String = SyncStatus.synced.rawValue
    var lastSyncedAt: Date?
    
    // Content
    var title: String
    var body: String
    var imageURL: URL?
    
    // Status
    var isRead: Bool
    var isArchived: Bool
    
    // Relationships
    var user: User?          // Who receives the notification
    var sourceUser: User?    // Who triggered the notification (if applicable)
    var response: VideoResponse?  // Related video (if applicable)
    var prompt: Prompt?      // Related prompt (if applicable)
    
    // Deep linking
    var deepLink: String?    // URL scheme for in-app navigation
    
    init(id: String,
         type: NotificationType,
         title: String,
         body: String,
         user: User?,
         sourceUser: User? = nil,
         response: VideoResponse? = nil,
         prompt: Prompt? = nil,
         deepLink: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.user = user
        self.sourceUser = sourceUser
        self.response = response
        self.prompt = prompt
        self.deepLink = deepLink
        self.isRead = false
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - SyncableModel
    static var collectionPath: String {
        return "notifications"
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Notification {
        guard let typeRaw = data["type"] as? String,
              let type = NotificationType(rawValue: typeRaw),
              let title = data["title"] as? String,
              let body = data["body"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let isRead = data["isRead"] as? Bool,
              let isArchived = data["isArchived"] as? Bool else {
            throw SyncError.invalidData("Missing required fields in Notification Firestore data")
        }
        
        let notification = Notification(id: id,
                                     type: type,
                                     title: title,
                                     body: body,
                                     user: nil)  // Relationships will be populated by sync service
        
        notification.createdAt = createdAtTimestamp.dateValue()
        notification.updatedAt = updatedAtTimestamp.dateValue()
        notification.isRead = isRead
        notification.isArchived = isArchived
        notification.syncStatus = data["syncStatus"] as? String ?? SyncStatus.synced.rawValue
        
        if let lastSyncedAtTimestamp = data["lastSyncedAt"] as? Timestamp {
            notification.lastSyncedAt = lastSyncedAtTimestamp.dateValue()
        }
        
        if let imageURLString = data["imageURL"] as? String {
            notification.imageURL = URL(string: imageURLString)
        }
        
        notification.deepLink = data["deepLink"] as? String
        
        return notification
    }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "title": title,
            "body": body,
            "isRead": isRead,
            "isArchived": isArchived,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "syncStatus": syncStatus
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        
        if let imageURL = imageURL {
            data["imageURL"] = imageURL.absoluteString
        }
        
        if let user = user {
            data["userId"] = user.id
        }
        
        if let sourceUser = sourceUser {
            data["sourceUserId"] = sourceUser.id
        }
        
        if let response = response {
            data["responseId"] = response.id
        }
        
        if let prompt = prompt {
            data["promptId"] = prompt.id
        }
        
        if let deepLink = deepLink {
            data["deepLink"] = deepLink
        }
        
        return data
    }
    
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Notification ID cannot be empty")
        }
        if title.isEmpty {
            throw SyncError.invalidData("Notification title cannot be empty")
        }
        if body.isEmpty {
            throw SyncError.invalidData("Notification body cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: Notification) -> Bool {
        return self.updatedAt != other.updatedAt
    }
    
    func mergeChanges(from other: Notification) throws -> Notification {
        // Use the most recent version
        if other.updatedAt > self.updatedAt {
            return other
        }
        return self
    }
}

// MARK: - Enums
extension Notification {
    enum NotificationType: String, Codable {
        case newPrompt
        case newResponse
        case newComment
        case newFollower
        case followRequest
        case mention
        case like
        case reminder
        case system
    }
} 