import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class VideoResponse {
    // Core properties
    let id: String            // Firestore document ID
    var createdAt: Date
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String
    var lastSyncedAt: Date?
    
    // Content metadata
    var duration: TimeInterval
    var thumbnailURL: URL?
    var videoURL: URL?        // URL to cloud storage
    var localVideoPath: String? // Path to local storage while processing
    var transcription: String?
    
    // Status tracking
    var status: Status
    var uploadProgress: Double
    var processingMessage: String?
    
    // Relationships
    var user: User?          // Who created the response
    var prompt: Prompt?      // Which prompt this responds to
    @Relationship(deleteRule: .cascade) var comments: [Comment]
    
    // Engagement metrics
    var viewCount: Int
    var likeCount: Int
    var commentCount: Int
    var shareCount: Int
    
    // Privacy and visibility
    var visibility: Visibility
    var allowComments: Bool
    
    init(id: String,
         user: User?,
         prompt: Prompt?,
         localVideoPath: String? = nil,
         duration: TimeInterval = 0,
         visibility: Visibility = .public) {
        self.id = id
        self.user = user
        self.prompt = prompt
        self.localVideoPath = localVideoPath
        self.duration = duration
        self.visibility = visibility
        self.status = .draft
        self.uploadProgress = 0
        self.viewCount = 0
        self.likeCount = 0
        self.commentCount = 0
        self.shareCount = 0
        self.allowComments = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = SyncStatus.synced.rawValue
        self.comments = []
    }
    
    // MARK: - Enums
    enum Status: String, Codable {
        case draft
        case uploading
        case processing
        case ready
        case failed
    }
    
    enum Visibility: String, Codable {
        case `public`
        case unlisted
        case `private`
    }
}

// MARK: - SyncableModel Conformance
extension VideoResponse: SyncableModel {
    static var collectionPath: String { "responses" }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "duration": duration,
            "status": status.rawValue,
            "uploadProgress": uploadProgress,
            "viewCount": viewCount,
            "likeCount": likeCount,
            "commentCount": commentCount,
            "shareCount": shareCount,
            "visibility": visibility.rawValue,
            "allowComments": allowComments,
            "syncStatus": syncStatus
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        if let thumbnailURL = thumbnailURL {
            data["thumbnailURL"] = thumbnailURL.absoluteString
        }
        if let videoURL = videoURL {
            data["videoURL"] = videoURL.absoluteString
        }
        if let transcription = transcription {
            data["transcription"] = transcription
        }
        if let processingMessage = processingMessage {
            data["processingMessage"] = processingMessage
        }
        if let user = user {
            data["userId"] = user.id
        }
        if let prompt = prompt {
            data["promptId"] = prompt.id
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> VideoResponse {
        let response = VideoResponse(id: id, user: nil, prompt: nil)
        
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            response.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            response.updatedAt = updatedAtTimestamp.dateValue()
        }
        if let lastSyncedAtTimestamp = data["lastSyncedAt"] as? Timestamp {
            response.lastSyncedAt = lastSyncedAtTimestamp.dateValue()
        }
        if let duration = data["duration"] as? TimeInterval {
            response.duration = duration
        }
        if let thumbnailURLString = data["thumbnailURL"] as? String {
            response.thumbnailURL = URL(string: thumbnailURLString)
        }
        if let videoURLString = data["videoURL"] as? String {
            response.videoURL = URL(string: videoURLString)
        }
        if let transcription = data["transcription"] as? String {
            response.transcription = transcription
        }
        if let statusRawValue = data["status"] as? String,
           let status = Status(rawValue: statusRawValue) {
            response.status = status
        }
        if let uploadProgress = data["uploadProgress"] as? Double {
            response.uploadProgress = uploadProgress
        }
        if let processingMessage = data["processingMessage"] as? String {
            response.processingMessage = processingMessage
        }
        if let viewCount = data["viewCount"] as? Int {
            response.viewCount = viewCount
        }
        if let likeCount = data["likeCount"] as? Int {
            response.likeCount = likeCount
        }
        if let commentCount = data["commentCount"] as? Int {
            response.commentCount = commentCount
        }
        if let shareCount = data["shareCount"] as? Int {
            response.shareCount = shareCount
        }
        if let visibilityRawValue = data["visibility"] as? String,
           let visibility = Visibility(rawValue: visibilityRawValue) {
            response.visibility = visibility
        }
        if let allowComments = data["allowComments"] as? Bool {
            response.allowComments = allowComments
        }
        if let syncStatus = data["syncStatus"] as? String {
            response.syncStatus = syncStatus
        }
        
        return response
    }
    
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("VideoResponse id cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: VideoResponse) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: VideoResponse) throws -> VideoResponse {
        // Use the most recent version's data
        if self.updatedAt > other.updatedAt {
            other.duration = self.duration
            other.thumbnailURL = self.thumbnailURL
            other.videoURL = self.videoURL
            other.transcription = self.transcription
            other.status = self.status
            other.uploadProgress = self.uploadProgress
            other.processingMessage = self.processingMessage
            other.visibility = self.visibility
            other.allowComments = self.allowComments
        }
        
        // Always take the highest counts
        other.viewCount = max(self.viewCount, other.viewCount)
        other.likeCount = max(self.likeCount, other.likeCount)
        other.commentCount = max(self.commentCount, other.commentCount)
        other.shareCount = max(self.shareCount, other.shareCount)
        
        // Keep track of sync status
        other.syncStatus = SyncStatus.pendingUpload.rawValue
        other.lastSyncedAt = Date()
        other.updatedAt = Date()
        
        return other
    }
} 