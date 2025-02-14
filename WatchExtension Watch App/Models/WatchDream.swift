import Foundation
import SwiftData

enum DreamVideoStyle: String, Codable {
    case realistic
    case animated
    case cursed
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
final class WatchDream {
    @Attribute(.unique) var dreamId: UUID
    var userId: String
    var title: String
    var dreamDescription: String
    var date: Date
    var audioURL: URL?
    var localAudioPath: String?
    var createdAt: Date
    var updatedAt: Date
    var transcript: String?
    var videoStyle: DreamVideoStyle?
    
    // Watch-specific sync properties
    var needsUploadToPhone: Bool
    private var _watchSyncStatus: String = WatchSyncStatus.pending.rawValue
    private var _watchSyncError: String?
    var syncProgress: Double = 0
    
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
    
    init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        description: String = "",
        date: Date = Date(),
        audioURL: URL? = nil,
        localAudioPath: String? = nil,
        transcript: String? = nil,
        needsUploadToPhone: Bool = true,
        videoStyle: DreamVideoStyle? = nil
    ) {
        self.dreamId = id
        self.userId = userId
        self.title = title
        self.dreamDescription = description
        self.date = date
        self.audioURL = audioURL
        self.localAudioPath = localAudioPath
        self.createdAt = date
        self.updatedAt = date
        self.transcript = transcript
        self.needsUploadToPhone = needsUploadToPhone
        self.videoStyle = videoStyle
    }
} 