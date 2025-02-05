import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Tag {
    var value: String
    var prompt: Prompt?
    
    init(value: String) {
        self.value = value
    }
}

@Model
final class Prompt: SyncableModel, PersistentModelWithStringID {
    // Core properties
    @Attribute(.unique) var id: String = ""
    var title: String = ""
    var promptDescription: String = ""
    var category: String = ""
    var difficulty: Int = 1
    var isActive: Bool = true
    @Relationship(deleteRule: .cascade) var tagObjects: [Tag] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var expiresAt: Date? = nil
    
    // Sync properties
    var syncStatus: String = SyncStatus.synced.rawValue
    var lastSyncedAt: Date? = nil
    static var collectionPath: String { "prompts" }
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \VideoResponse.prompt) var responses: [VideoResponse] = []
    
    var tags: [String] {
        get {
            tagObjects.map { $0.value }
        }
        set {
            tagObjects = newValue.map { Tag(value: $0) }
            tagObjects.forEach { $0.prompt = self }
        }
    }
    
    // PersistentModelWithStringID conformance
    var persistentModelID: String {
        id
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         category: String,
         difficulty: Int = 1,
         isActive: Bool = true,
         tags: [String] = [],
         expiresAt: Date? = nil) {
        self.id = id
        self.title = title
        self.promptDescription = description
        self.category = category
        self.difficulty = difficulty
        self.isActive = isActive
        self.tags = tags
        self.expiresAt = expiresAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = SyncStatus.synced.rawValue
    }
    
    // MARK: - SyncableModel
    func toFirestoreData() throws -> [String: Any] {
        try validate()  // Validate before converting to Firestore data
        
        var data: [String: Any] = [
            "title": title,
            "description": promptDescription,
            "category": category,
            "difficulty": difficulty,
            "isActive": isActive,
            "tags": tags,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "syncStatus": syncStatus
        ]
        
        if let expiresAt = expiresAt {
            data["expiresAt"] = Timestamp(date: expiresAt)
        }
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Prompt {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String,
              let difficulty = data["difficulty"] as? Int,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            throw SyncError.invalidData("Missing required fields in Prompt Firestore data")
        }
        
        let isActive = data["isActive"] as? Bool ?? true
        let tags = data["tags"] as? [String] ?? []
        
        let prompt = Prompt(id: id,
                          title: title,
                          description: description,
                          category: category,
                          difficulty: difficulty)
        
        prompt.createdAt = createdAt
        prompt.updatedAt = updatedAt
        prompt.isActive = isActive
        prompt.tags = tags
        
        if let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() {
            prompt.expiresAt = expiresAt
        }
        if let syncStatus = data["syncStatus"] as? String {
            prompt.syncStatus = syncStatus
        }
        if let lastSyncedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue() {
            prompt.lastSyncedAt = lastSyncedAt
        }
        
        return prompt
    }
    
    // MARK: - Protocol Conformance
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Prompt ID cannot be empty")
        }
        if title.isEmpty {
            throw SyncError.invalidData("Prompt title cannot be empty")
        }
        if promptDescription.isEmpty {
            throw SyncError.invalidData("Prompt description cannot be empty")
        }
        if category.isEmpty {
            throw SyncError.invalidData("Prompt category cannot be empty")
        }
        if difficulty < 1 || difficulty > 4 {
            throw SyncError.invalidData("Invalid difficulty format")
        }
    }
    
    func hasConflictsWith(_ other: Prompt) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: Prompt) throws -> Prompt {
        if other.updatedAt > self.updatedAt {
            self.title = other.title
            self.promptDescription = other.promptDescription
            self.category = other.category
            self.difficulty = other.difficulty
            self.isActive = other.isActive
            self.tags = other.tags
            self.updatedAt = Date()
            self.lastSyncedAt = Date()
        }
        return self
    }
}

// MARK: - Enums
extension Prompt {
    enum Category: String, Codable {
        case daily
        case weekly
        case challenge
        case community
        case special
    }
    
    enum Difficulty: String, Codable {
        case easy
        case medium
        case hard
        case expert
    }
} 