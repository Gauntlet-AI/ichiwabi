import Foundation
import SwiftData
import FirebaseFirestore

enum DreamVideoStyle: String, Codable {
    case realistic
    case animated
    case cursed
}

enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
    case aiGenerating  // New status for AI generation
    case aiCompleted   // New status for completed AI generation
}

@Model
final class Dream {
    @Attribute(.unique) var dreamId: UUID
    var userId: String
    var title: String
    var dreamDescription: String
    var date: Date
    var videoURL: URL
    var audioURL: URL?
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
    private var _processingStatus: String?  // Internal storage
    var processingError: String?
    
    // AI-specific properties
    var isAIGenerated: Bool = false  // Whether this dream has been AI-generated
    var originalVideoURL: URL?  // Store the original video URL when AI-generated
    var aiGenerationDate: Date?  // When the AI generation was completed
    
    // Computed property to handle migration
    var processingStatus: ProcessingStatus {
        get {
            if let statusString = _processingStatus,
               let status = ProcessingStatus(rawValue: statusString) {
                return status
            }
            return .pending
        }
        set {
            _processingStatus = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        description: String,
        date: Date,
        videoURL: URL,
        audioURL: URL? = nil,
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
        processingProgress: Double = 0,
        processingStatus: ProcessingStatus = .pending,
        processingError: String? = nil
    ) {
        self.dreamId = id
        self.userId = userId
        self.title = title
        self.dreamDescription = description
        self.date = date
        self.videoURL = videoURL
        self.audioURL = audioURL
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
        self._processingStatus = processingStatus.rawValue
        self.processingError = processingError
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
            "dreamDate": Timestamp(date: dreamDate),
            "isSynced": isSynced,
            "isProcessing": isProcessing,
            "processingProgress": processingProgress,
            "processingStatus": processingStatus.rawValue,
            "isAIGenerated": isAIGenerated  // Add AI generation flag
        ]
        
        // Add optional fields
        if let audioURL = audioURL {
            data["audioURL"] = audioURL.absoluteString
        }
        if let transcript = transcript {
            data["transcript"] = transcript
        }
        if !tags.isEmpty {
            data["tags"] = tags
        }
        if let category = category {
            data["category"] = category
        }
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        if let localVideoPath = localVideoPath {
            data["localVideoPath"] = localVideoPath
        }
        if let localAudioPath = localAudioPath {
            data["localAudioPath"] = localAudioPath
        }
        if let videoStyle = videoStyle {
            data["videoStyle"] = videoStyle.rawValue
        }
        if let processingError = processingError {
            data["processingError"] = processingError
        }
        // Add AI-specific optional fields
        if let originalVideoURL = originalVideoURL {
            data["originalVideoURL"] = originalVideoURL.absoluteString
        }
        if let aiGenerationDate = aiGenerationDate {
            data["aiGenerationDate"] = Timestamp(date: aiGenerationDate)
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> Dream? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let videoURLString = data["videoURL"] as? String,
              let videoURL = URL(string: videoURLString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let dreamDateTimestamp = data["dreamDate"] as? Timestamp else {
            return nil
        }
        
        // Handle optional video style
        var videoStyle: DreamVideoStyle?
        if let styleString = data["videoStyle"] as? String {
            videoStyle = DreamVideoStyle(rawValue: styleString)
        }
        
        // Handle optional processing status
        let processingStatus: ProcessingStatus
        if let statusString = data["processingStatus"] as? String,
           let status = ProcessingStatus(rawValue: statusString) {
            processingStatus = status
        } else {
            processingStatus = .pending
        }
        
        // Handle optional audio URL
        var audioURL: URL?
        if let audioURLString = data["audioURL"] as? String {
            audioURL = URL(string: audioURLString)
        }
        
        var processingError: String?
        if let error = data["processingError"] as? String {
            processingError = error
        }
        
        // Handle AI-specific fields
        var originalVideoURL: URL?
        if let originalURLString = data["originalVideoURL"] as? String {
            originalVideoURL = URL(string: originalURLString)
        }
        
        var aiGenerationDate: Date?
        if let aiGenTimestamp = data["aiGenerationDate"] as? Timestamp {
            aiGenerationDate = aiGenTimestamp.dateValue()
        }
        
        let dream = Dream(
            id: id,
            userId: userId,
            title: title,
            description: description,
            date: dateTimestamp.dateValue(),
            videoURL: videoURL,
            audioURL: audioURL,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            transcript: data["transcript"] as? String,
            tags: data["tags"] as? [String] ?? [],
            category: data["category"] as? String,
            isSynced: data["isSynced"] as? Bool ?? false,
            lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue(),
            dreamDate: dreamDateTimestamp.dateValue(),
            localVideoPath: data["localVideoPath"] as? String,
            localAudioPath: data["localAudioPath"] as? String,
            videoStyle: videoStyle,
            isProcessing: data["isProcessing"] as? Bool ?? false,
            processingProgress: data["processingProgress"] as? Double ?? 0,
            processingStatus: processingStatus,
            processingError: processingError
        )
        
        // Set AI-specific properties
        dream.isAIGenerated = data["isAIGenerated"] as? Bool ?? false
        dream.originalVideoURL = originalVideoURL
        dream.aiGenerationDate = aiGenerationDate
        
        return dream
    }
} 