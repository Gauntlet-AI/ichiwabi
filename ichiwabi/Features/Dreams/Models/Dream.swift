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
        print("🔍 Dream.init - Setting processingStatus to: \(processingStatus.rawValue)")
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
        print("🔍 Creating firestoreData with processingStatus: \(processingStatus.rawValue)")
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
            "processingProgress": processingProgress,
            "processingStatus": processingStatus.rawValue
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
        if let audioURL = audioURL {
            data["audioURL"] = audioURL.absoluteString
        }
        if let processingError = processingError {
            data["processingError"] = processingError
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> Dream? {
        print("🔍 Attempting to create Dream from Firestore data")
        print("🔍 Raw processingStatus from Firestore: \(data["processingStatus"] as? String ?? "nil")")
        
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
        else {
            print("❌ Failed to extract required fields from Firestore data")
            return nil
        }
        
        // Get processing status with a default value
        let processingStatus: ProcessingStatus
        if let statusString = data["processingStatus"] as? String {
            print("🔍 Found processingStatus string: \(statusString)")
            if let status = ProcessingStatus(rawValue: statusString) {
                print("🔍 Successfully created ProcessingStatus from string")
                processingStatus = status
            } else {
                print("⚠️ Invalid processingStatus value, defaulting to .pending")
                processingStatus = .pending
            }
        } else {
            print("⚠️ No processingStatus in data, defaulting to .pending")
            processingStatus = .pending
        }
        
        var videoStyle: DreamVideoStyle?
        if let styleString = data["videoStyle"] as? String {
            videoStyle = DreamVideoStyle(rawValue: styleString)
        }
        
        // Convert audio URL string to URL if it exists
        let audioURL: URL?
        if let audioURLString = data["audioURL"] as? String {
            audioURL = URL(string: audioURLString)
        } else {
            audioURL = nil
        }
        
        var processingError: String?
        if let error = data["processingError"] as? String {
            processingError = error
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
        
        print("🔍 Successfully created Dream with processingStatus: \(dream.processingStatus.rawValue)")
        return dream
    }
} 