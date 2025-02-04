import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Prompt: SyncableModel {
    // Core properties
    var id: String            // Firestore document ID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var activeDate: Date      // The date this prompt is active for
    var expiresAt: Date?      // Optional expiration for time-sensitive prompts
    
    // Categorization
    var category: Category
    var tags: [String]
    var difficulty: Difficulty
    
    // Prompt metadata
    var isActive: Bool
    var isUserGenerated: Bool
    var createdBy: User?      // Only for user-generated prompts
    var totalResponses: Int
    
    // Sync properties
    var syncStatus: String = SyncStatus.synced.rawValue
    var lastSyncedAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var responses: [VideoResponse] = []
    
    // MARK: - Static Properties
    static var collectionPath: String {
        return "prompts"
    }
    
    init(id: String,
         text: String,
         activeDate: Date,
         category: Category = .daily,
         tags: [String] = [],
         difficulty: Difficulty = .medium,
         isUserGenerated: Bool = false,
         createdBy: User? = nil) {
        self.id = id
        self.text = text
        self.activeDate = activeDate
        self.category = category
        self.tags = tags
        self.difficulty = difficulty
        self.isUserGenerated = isUserGenerated
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
        self.totalResponses = 0
    }
    
    // MARK: - SyncableModel
    func toFirestoreData() throws -> [String: Any] {
        try validate()  // Validate before converting to Firestore data
        
        var data: [String: Any] = [
            "text": text,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "activeDate": Timestamp(date: activeDate),
            "category": category.rawValue,
            "tags": tags,
            "difficulty": difficulty.rawValue,
            "isActive": isActive,
            "isUserGenerated": isUserGenerated,
            "totalResponses": totalResponses,
            "syncStatus": syncStatus
        ]
        
        if let expiresAt = expiresAt {
            data["expiresAt"] = Timestamp(date: expiresAt)
        }
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        if let createdBy = createdBy {
            data["createdBy"] = createdBy.id
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Prompt {
        guard let text = data["text"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue(),
              let activeDate = (data["activeDate"] as? Timestamp)?.dateValue() else {
            throw SyncError.invalidData("Missing required fields in Prompt Firestore data")
        }
        
        let category = Category(rawValue: data["category"] as? String ?? "daily") ?? .daily
        let tags = data["tags"] as? [String] ?? []
        let difficulty = Difficulty(rawValue: data["difficulty"] as? String ?? "medium") ?? .medium
        let isActive = data["isActive"] as? Bool ?? true
        let isUserGenerated = data["isUserGenerated"] as? Bool ?? false
        let totalResponses = data["totalResponses"] as? Int ?? 0
        
        let prompt = Prompt(id: id,
                          text: text,
                          activeDate: activeDate,
                          category: category,
                          tags: tags,
                          difficulty: difficulty,
                          isUserGenerated: isUserGenerated)
        
        prompt.createdAt = createdAt
        prompt.updatedAt = updatedAt
        prompt.isActive = isActive
        prompt.totalResponses = totalResponses
        
        if let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() {
            prompt.expiresAt = expiresAt
        }
        if let lastSyncedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue() {
            prompt.lastSyncedAt = lastSyncedAt
        }
        if let syncStatus = data["syncStatus"] as? String {
            prompt.syncStatus = syncStatus
        }
        
        return prompt
    }
    
    // MARK: - Protocol Conformance
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Prompt ID cannot be empty")
        }
        if text.isEmpty {
            throw SyncError.invalidData("Prompt text cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: Prompt) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: Prompt) throws -> Prompt {
        if other.updatedAt > self.updatedAt {
            self.text = other.text
            self.activeDate = other.activeDate
            self.expiresAt = other.expiresAt
            self.category = other.category
            self.tags = other.tags
            self.difficulty = other.difficulty
            self.isActive = other.isActive
            self.totalResponses = other.totalResponses
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