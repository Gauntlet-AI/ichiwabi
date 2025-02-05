import Foundation
import SwiftData
import FirebaseFirestore
import Observation

@Model
final class Settings {
    // Core properties
    @Attribute(.unique) var id: String            // Unique identifier (usually user's ID)
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String
    var lastSyncedAt: Date?
    
    // Video creation settings
    var defaultVideoQuality: VideoQuality
    var defaultVisibility: VideoResponse.Visibility
    var enableAutoSave: Bool
    var maxVideoDuration: TimeInterval
    
    // Notification preferences
    var dailyPromptReminder: Bool
    var reminderTime: Date?  // Time of day for daily reminders
    var notifyOnComments: Bool
    var notifyOnLikes: Bool
    var notifyOnFollows: Bool
    var notifyOnMentions: Bool
    
    // Content preferences
    var autoplayVideos: Bool
    var downloadOverCellular: Bool
    var preferredPromptCategories: [Prompt.Category]
    
    // Privacy settings
    var allowFriendRequests: Bool
    var showActivityStatus: Bool
    var allowMentions: Bool
    
    // Accessibility
    var enableClosedCaptions: Bool
    var reduceMotion: Bool
    var enableVoiceOver: Bool
    
    // Cache settings
    var maxCacheSize: Int
    var autoClearCache: Bool
    
    init(id: String) {
        self.id = id
        self.updatedAt = Date()
        self.syncStatus = SyncStatus.synced.rawValue
        
        // Video creation defaults
        self.defaultVideoQuality = .high
        self.defaultVisibility = .public
        self.enableAutoSave = true
        self.maxVideoDuration = 300 // 5 minutes
        
        // Notification defaults
        self.dailyPromptReminder = true
        self.notifyOnComments = true
        self.notifyOnLikes = true
        self.notifyOnFollows = true
        self.notifyOnMentions = true
        
        // Content preferences defaults
        self.autoplayVideos = true
        self.downloadOverCellular = false
        self.preferredPromptCategories = []
        
        // Privacy defaults
        self.allowFriendRequests = true
        self.showActivityStatus = true
        self.allowMentions = true
        
        // Accessibility defaults
        self.enableClosedCaptions = false
        self.reduceMotion = false
        self.enableVoiceOver = false
        
        // Cache defaults
        self.maxCacheSize = 1024 * 1024 * 1024 // 1GB
        self.autoClearCache = true
    }
}

// MARK: - SyncableModel Conformance
extension Settings: SyncableModel {
    static var collectionPath: String { "settings" }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Settings {
        guard let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw SyncError.invalidData("Missing required fields in Settings Firestore data")
        }
        
        let settings = Settings(id: id)
        settings.updatedAt = updatedAtTimestamp.dateValue()
        settings.syncStatus = data["syncStatus"] as? String ?? SyncStatus.synced.rawValue
        
        if let lastSyncedAtTimestamp = data["lastSyncedAt"] as? Timestamp {
            settings.lastSyncedAt = lastSyncedAtTimestamp.dateValue()
        }
        
        // Video creation settings
        if let quality = data["defaultVideoQuality"] as? String {
            settings.defaultVideoQuality = VideoQuality(rawValue: quality) ?? .high
        }
        if let visibility = data["defaultVisibility"] as? String {
            settings.defaultVisibility = VideoResponse.Visibility(rawValue: visibility) ?? .public
        }
        settings.enableAutoSave = data["enableAutoSave"] as? Bool ?? true
        settings.maxVideoDuration = data["maxVideoDuration"] as? TimeInterval ?? 300
        
        // Notification preferences
        settings.dailyPromptReminder = data["dailyPromptReminder"] as? Bool ?? true
        if let reminderTimeTimestamp = data["reminderTime"] as? Timestamp {
            settings.reminderTime = reminderTimeTimestamp.dateValue()
        }
        settings.notifyOnComments = data["notifyOnComments"] as? Bool ?? true
        settings.notifyOnLikes = data["notifyOnLikes"] as? Bool ?? true
        settings.notifyOnFollows = data["notifyOnFollows"] as? Bool ?? true
        settings.notifyOnMentions = data["notifyOnMentions"] as? Bool ?? true
        
        // Content preferences
        settings.autoplayVideos = data["autoplayVideos"] as? Bool ?? true
        settings.downloadOverCellular = data["downloadOverCellular"] as? Bool ?? false
        if let categories = data["preferredPromptCategories"] as? [String] {
            settings.preferredPromptCategories = categories.compactMap { Prompt.Category(rawValue: $0) }
        }
        
        // Privacy settings
        settings.allowFriendRequests = data["allowFriendRequests"] as? Bool ?? true
        settings.showActivityStatus = data["showActivityStatus"] as? Bool ?? true
        settings.allowMentions = data["allowMentions"] as? Bool ?? true
        
        // Accessibility settings
        settings.enableClosedCaptions = data["enableClosedCaptions"] as? Bool ?? false
        settings.reduceMotion = data["reduceMotion"] as? Bool ?? false
        settings.enableVoiceOver = data["enableVoiceOver"] as? Bool ?? false
        
        // Cache settings
        settings.maxCacheSize = data["maxCacheSize"] as? Int ?? 1024 * 1024 * 1024
        settings.autoClearCache = data["autoClearCache"] as? Bool ?? true
        
        return settings
    }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "updatedAt": Timestamp(date: updatedAt),
            "syncStatus": syncStatus
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        
        // Video creation settings
        data["defaultVideoQuality"] = defaultVideoQuality.rawValue
        data["defaultVisibility"] = defaultVisibility.rawValue
        data["enableAutoSave"] = enableAutoSave
        data["maxVideoDuration"] = maxVideoDuration
        
        // Notification preferences
        data["dailyPromptReminder"] = dailyPromptReminder
        if let reminderTime = reminderTime {
            data["reminderTime"] = Timestamp(date: reminderTime)
        }
        data["notifyOnComments"] = notifyOnComments
        data["notifyOnLikes"] = notifyOnLikes
        data["notifyOnFollows"] = notifyOnFollows
        data["notifyOnMentions"] = notifyOnMentions
        
        // Content preferences
        data["autoplayVideos"] = autoplayVideos
        data["downloadOverCellular"] = downloadOverCellular
        data["preferredPromptCategories"] = preferredPromptCategories.map { $0.rawValue }
        
        // Privacy settings
        data["allowFriendRequests"] = allowFriendRequests
        data["showActivityStatus"] = showActivityStatus
        data["allowMentions"] = allowMentions
        
        // Accessibility settings
        data["enableClosedCaptions"] = enableClosedCaptions
        data["reduceMotion"] = reduceMotion
        data["enableVoiceOver"] = enableVoiceOver
        
        // Cache settings
        data["maxCacheSize"] = maxCacheSize
        data["autoClearCache"] = autoClearCache
        
        return data
    }
    
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Settings ID cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: Settings) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: Settings) throws -> Settings {
        if other.updatedAt > self.updatedAt {
            // Update all properties from other
            self.updatedAt = other.updatedAt
            self.defaultVideoQuality = other.defaultVideoQuality
            self.defaultVisibility = other.defaultVisibility
            self.enableAutoSave = other.enableAutoSave
            self.maxVideoDuration = other.maxVideoDuration
            self.dailyPromptReminder = other.dailyPromptReminder
            self.reminderTime = other.reminderTime
            self.notifyOnComments = other.notifyOnComments
            self.notifyOnLikes = other.notifyOnLikes
            self.notifyOnFollows = other.notifyOnFollows
            self.notifyOnMentions = other.notifyOnMentions
            self.autoplayVideos = other.autoplayVideos
            self.downloadOverCellular = other.downloadOverCellular
            self.preferredPromptCategories = other.preferredPromptCategories
            self.allowFriendRequests = other.allowFriendRequests
            self.showActivityStatus = other.showActivityStatus
            self.allowMentions = other.allowMentions
            self.enableClosedCaptions = other.enableClosedCaptions
            self.reduceMotion = other.reduceMotion
            self.enableVoiceOver = other.enableVoiceOver
            self.maxCacheSize = other.maxCacheSize
            self.autoClearCache = other.autoClearCache
        }
        
        self.syncStatus = SyncStatus.pendingUpload.rawValue
        self.lastSyncedAt = Date()
        self.updatedAt = Date()
        
        return self
    }
} 