import Foundation
import SwiftData
import FirebaseFirestore

enum DreamVideoStyle: String, Codable {
    case realistic
    case animated
    case cursed
}

@Model
final class Dream {
    @Attribute(.unique) var dreamId: UUID
    var userId: String
    var title: String
    var dreamDescription: String
    var date: Date
    var videoURL: URL
    var localVideoPath: String?
    var localAudioPath: String?  // Path to the recorded audio file
    var createdAt: Date
    var updatedAt: Date
    var transcript: String?
    var tags: [String] = []
    var category: String?
    var isSynced: Bool
    var lastSyncedAt: Date?
    var dreamDate: Date
    var videoStyle: DreamVideoStyle?  // Selected video generation style
    var isProcessing: Bool  // Whether the dream is being processed by AI
    var processingProgress: Double  // Progress of AI processing (0-1)
    
    init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        description: String,
        date: Date,
        videoURL: URL,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        transcript: String? = nil,
        tags: [String] = [],
        category: String? = nil,
        isSynced: Bool = false,
        lastSyncedAt: Date? = nil,
        dreamDate: Date? = nil,
        localVideoPath: String? = nil,
        localAudioPath: String? = nil,
        videoStyle: DreamVideoStyle? = nil,
        isProcessing: Bool = false,
        processingProgress: Double = 0
    ) {
        self.dreamId = id
        self.userId = userId
        self.title = title
        self.dreamDescription = description
        self.date = date
        self.videoURL = videoURL
        self.localVideoPath = localVideoPath
        self.localAudioPath = localAudioPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transcript = transcript
        self.tags = tags
        self.category = category
        self.isSynced = isSynced
        self.lastSyncedAt = lastSyncedAt
        self.dreamDate = dreamDate ?? date
        self.videoStyle = videoStyle
        self.isProcessing = isProcessing
        self.processingProgress = processingProgress
    }
}

// MARK: - Firestore Conversion
extension Dream {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": dreamId.uuidString,
            "userId": userId,
            "title": title,
            "description": dreamDescription,
            "date": Timestamp(date: date),
            "videoURL": videoURL.absoluteString,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "tags": tags,
            "isSynced": isSynced,
            "dreamDate": Timestamp(date: dreamDate),
            "isProcessing": isProcessing,
            "processingProgress": processingProgress
        ]
        
        // Add optional fields
        if let transcript = transcript {
            data["transcript"] = transcript
        }
        if let category = category {
            data["category"] = category
        }
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        if let videoStyle = videoStyle {
            data["videoStyle"] = videoStyle.rawValue
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> Dream? {
        guard
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let userId = data["userId"] as? String,
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let dateTimestamp = data["date"] as? Timestamp,
            let videoURLString = data["videoURL"] as? String,
            let videoURL = URL(string: videoURLString),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
            let dreamDateTimestamp = data["dreamDate"] as? Timestamp
        else { return nil }
        
        var videoStyle: DreamVideoStyle?
        if let styleString = data["videoStyle"] as? String {
            videoStyle = DreamVideoStyle(rawValue: styleString)
        }
        
        return Dream(
            id: id,
            userId: userId,
            title: title,
            description: description,
            date: dateTimestamp.dateValue(),
            videoURL: videoURL,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            transcript: data["transcript"] as? String,
            tags: data["tags"] as? [String] ?? [],
            category: data["category"] as? String,
            isSynced: data["isSynced"] as? Bool ?? false,
            lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue(),
            dreamDate: dreamDateTimestamp.dateValue(),
            videoStyle: videoStyle,
            isProcessing: data["isProcessing"] as? Bool ?? false,
            processingProgress: data["processingProgress"] as? Double ?? 0
        )
    }
} 