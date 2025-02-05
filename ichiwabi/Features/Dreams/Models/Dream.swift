import Foundation
import SwiftData
import FirebaseFirestore

@Model
class Dream {
    // Core properties
    @Attribute(.unique) var id: String
    var title: String
    var transcript: String?
    var videoURL: String?
    var recordedDate: Date
    var dreamDate: Date
    
    // Metadata
    var tags: [String]
    var category: String?
    var createdAt: Date
    var updatedAt: Date
    var userId: String
    
    // Sync status
    var isSynced: Bool
    var lastSyncedAt: Date?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        transcript: String? = nil,
        videoURL: String? = nil,
        recordedDate: Date = Date(),
        dreamDate: Date,
        tags: [String] = [],
        category: String? = nil,
        userId: String,
        isSynced: Bool = false,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.videoURL = videoURL
        self.recordedDate = recordedDate
        self.dreamDate = dreamDate
        self.tags = tags
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = userId
        self.isSynced = isSynced
        self.lastSyncedAt = lastSyncedAt
    }
}

// MARK: - Firestore Conversion
extension Dream {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "recordedDate": Timestamp(date: recordedDate),
            "dreamDate": Timestamp(date: dreamDate),
            "tags": tags,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "userId": userId
        ]
        
        // Add optional fields
        if let transcript = transcript {
            data["transcript"] = transcript
        }
        if let videoURL = videoURL {
            data["videoURL"] = videoURL
        }
        if let category = category {
            data["category"] = category
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> Dream? {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let recordedDate = (data["recordedDate"] as? Timestamp)?.dateValue(),
            let dreamDate = (data["dreamDate"] as? Timestamp)?.dateValue(),
            let userId = data["userId"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue(),
            let tags = data["tags"] as? [String]
        else { return nil }
        
        let dream = Dream(
            id: id,
            title: title,
            transcript: data["transcript"] as? String,
            videoURL: data["videoURL"] as? String,
            recordedDate: recordedDate,
            dreamDate: dreamDate,
            tags: tags,
            category: data["category"] as? String,
            userId: userId
        )
        
        dream.createdAt = createdAt
        dream.updatedAt = updatedAt
        
        return dream
    }
} 