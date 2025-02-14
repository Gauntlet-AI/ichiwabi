import Foundation
import SwiftData

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
    case aiGenerating
    case aiCompleted
}

enum WatchSyncStatus: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
    case synced
}

enum WatchRecordingError: String, Codable {
    case noConnection
    case transferFailed
    case phoneNotReachable
    case audioUploadFailed
    case unknown
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
    var localAudioPath: String?
    var createdAt: Date
    var updatedAt: Date
    var transcript: String?
    var tags: [String] = []
    var category: String?
    var isSynced: Bool
    var lastSyncedAt: Date?
    var dreamDate: Date
    var videoStyle: DreamVideoStyle?
    var isProcessing: Bool
    var processingProgress: Double
    private var _processingStatus: String?
    var processingError: String?
    
    // AI-specific properties
    var isAIGenerated: Bool = false
    var originalVideoURL: URL?
    var aiGenerationDate: Date?
    
    // Watch-specific sync properties
    var isWatchRecording: Bool = false
    var needsUploadToPhone: Bool = false
    private var _watchSyncStatus: String = WatchSyncStatus.pending.rawValue
    private var _watchSyncError: String?
    
    // Computed properties for watch sync
    var watchSyncStatus: WatchSyncStatus {
        get {
            WatchSyncStatus(rawValue: _watchSyncStatus) ?? .pending
        }
        set {
            _watchSyncStatus = newValue.rawValue
        }
    }
    
    var watchSyncError: WatchRecordingError? {
        get {
            if let errorString = _watchSyncError {
                return WatchRecordingError(rawValue: errorString)
            }
            return nil
        }
        set {
            _watchSyncError = newValue?.rawValue
        }
    }
    
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