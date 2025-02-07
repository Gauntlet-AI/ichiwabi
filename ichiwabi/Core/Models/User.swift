import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class User: SyncableModel, PersistentModelWithStringID {
    // Core properties
    @Attribute(.unique) var id: String  // Firebase Auth UID
    var username: String
    var displayName: String
    var catchphrase: String?
    var avatarURL: URL?
    var createdAt: Date
    var lastActiveAt: Date
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String
    var lastSyncedAt: Date?
    static var collectionPath: String { "users" }
    
    // Authentication metadata
    var email: String
    var isEmailVerified: Bool
    var phoneNumber: String?
    
    // Profile completion
    var isProfileComplete: Bool = false
    var hasAcceptedTerms: Bool = false
    
    // Stats
    var streakCount: Int
    var lastStreakDate: Date?
    
    // Relationships (SwiftData)
    @Relationship(deleteRule: .cascade) var responses: [VideoResponse]
    @Relationship(deleteRule: .nullify) var following: [User]
    @Relationship(deleteRule: .nullify) var followers: [User]
    
    // Settings and preferences
    var notificationsEnabled: Bool
    var privacyMode: User.PrivacyMode
    
    init(id: String, 
         username: String, 
         displayName: String, 
         email: String,
         isEmailVerified: Bool = false) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.isEmailVerified = isEmailVerified
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.updatedAt = Date()
        self.syncStatus = ichiwabi.SyncStatus.synced.rawValue
        self.notificationsEnabled = true
        self.privacyMode = .publicMode
        self.responses = []
        self.following = []
        self.followers = []
        self.streakCount = 0
        // If we have an ID and username, the profile is complete
        self.isProfileComplete = true
        self.hasAcceptedTerms = true
    }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "username": username,
            "displayName": displayName,
            "createdAt": Timestamp(date: createdAt),
            "lastActiveAt": Timestamp(date: lastActiveAt),
            "updatedAt": Timestamp(date: updatedAt),
            "email": email,
            "isEmailVerified": isEmailVerified,
            "notificationsEnabled": notificationsEnabled,
            "privacyMode": privacyMode.rawValue,
            "followerCount": followers.count,
            "followingCount": following.count,
            "responseCount": responses.count,
            "isProfileComplete": isProfileComplete,
            "hasAcceptedTerms": hasAcceptedTerms,
            "streakCount": streakCount
        ]
        
        // Add optional fields only if they have values
        if let catchphrase = catchphrase {
            data["catchphrase"] = catchphrase
        }
        if let avatarURL = avatarURL?.absoluteString {
            data["avatarURL"] = avatarURL
        }
        if let phoneNumber = phoneNumber {
            data["phoneNumber"] = phoneNumber
        }
        if let lastStreakDate = lastStreakDate {
            data["lastStreakDate"] = Timestamp(date: lastStreakDate)
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> User {
        guard let username = data["username"] as? String,
              let displayName = data["displayName"] as? String,
              let email = data["email"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let lastActiveAtTimestamp = data["lastActiveAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw SyncError.invalidData("Missing required fields in Firestore data")
        }
        
        // Helper function to convert value to Bool
        func toBool(_ value: Any?) -> Bool {
            if let boolValue = value as? Bool {
                return boolValue
            }
            if let intValue = value as? Int {
                return intValue != 0
            }
            return false
        }
        
        let user = User(id: id,
                       username: username,
                       displayName: displayName,
                       email: email,
                       isEmailVerified: toBool(data["isEmailVerified"]))
        
        user.catchphrase = data["catchphrase"] as? String
        if let avatarURLString = data["avatarURL"] as? String {
            user.avatarURL = URL(string: avatarURLString)
        }
        user.phoneNumber = data["phoneNumber"] as? String
        user.notificationsEnabled = toBool(data["notificationsEnabled"])
        if let privacyModeString = data["privacyMode"] as? String,
           let privacyMode = User.PrivacyMode(rawValue: privacyModeString) {
            user.privacyMode = privacyMode
        }
        
        // Profile is complete if we have a username and ID
        user.isProfileComplete = true
        user.hasAcceptedTerms = true
        
        user.streakCount = data["streakCount"] as? Int ?? 0
        if let lastStreakTimestamp = data["lastStreakDate"] as? Timestamp {
            user.lastStreakDate = lastStreakTimestamp.dateValue()
        }
        
        user.createdAt = createdAtTimestamp.dateValue()
        user.lastActiveAt = lastActiveAtTimestamp.dateValue()
        user.updatedAt = updatedAtTimestamp.dateValue()
        
        return user
    }
    
    func validate() throws {
        guard !username.isEmpty else {
            throw SyncError.invalidData("Username cannot be empty")
        }
        guard !displayName.isEmpty else {
            throw SyncError.invalidData("Display name cannot be empty")
        }
        guard !email.isEmpty else {
            throw SyncError.invalidData("Email cannot be empty")
        }
        
        // Username format validation
        let usernameRegex = "^[a-zA-Z0-9_]{3,}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        guard usernamePredicate.evaluate(with: username) else {
            throw SyncError.invalidData("Username must be at least 3 characters and contain only letters, numbers, and underscores")
        }
        
        // Catchphrase length validation
        if let catchphrase = catchphrase, catchphrase.count > 50 {
            throw SyncError.invalidData("Catchphrase must be 50 characters or less")
        }
    }
    
    func hasConflictsWith(_ other: User) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: User) throws -> User {
        // Take the most recent changes for each field
        if other.updatedAt > self.updatedAt {
            self.username = other.username
            self.displayName = other.displayName
            self.catchphrase = other.catchphrase
            self.phoneNumber = other.phoneNumber
            self.privacyMode = other.privacyMode
            self.notificationsEnabled = other.notificationsEnabled
            self.streakCount = other.streakCount
            self.lastStreakDate = other.lastStreakDate
        }
        
        // Always preserve non-null avatar URL regardless of timestamp
        if let otherAvatarURL = other.avatarURL {
            self.avatarURL = otherAvatarURL
        }
        
        // Always consider profile complete if we have username and ID
        self.isProfileComplete = true
        self.hasAcceptedTerms = true
        
        // Always take the most recent activity timestamp
        self.lastActiveAt = max(self.lastActiveAt, other.lastActiveAt)
        self.updatedAt = Date()
        self.lastSyncedAt = Date()
        
        return self
    }
    
    var persistentModelID: String {
        return id
    }
}

// MARK: - Enums
extension User {
    enum PrivacyMode: String, Codable {
        case publicMode = "public"
        case friendsOnly = "friendsOnly"
        case privateMode = "private"
    }
} 