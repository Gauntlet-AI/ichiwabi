import Foundation
import SwiftData
import FirebaseFirestore
import Observation

@Model
final class Report {
    // Core properties
    let id: String            // Firestore document ID
    var createdAt: Date
    var updatedAt: Date
    
    // Sync properties
    var syncStatus: String
    var lastSyncedAt: Date?
    
    // Report details
    var type: ReportType
    var reason: ReportReason
    var reportDescription: String?  // Additional details from reporter
    var status: Status
    
    // Relationships
    var reporter: User?      // Who filed the report
    var reportedUser: User?  // User being reported (if applicable)
    var response: VideoResponse?  // Reported video (if applicable)
    var comment: Comment?    // Reported comment (if applicable)
    
    // Moderation
    var moderatorNotes: String?
    var moderatedBy: String?  // Moderator's ID
    var moderatedAt: Date?
    var actionTaken: ModeratorAction?
    
    init(id: String,
         type: ReportType,
         reason: ReportReason,
         description: String? = nil,
         reporter: User?,
         reportedUser: User? = nil,
         response: VideoResponse? = nil,
         comment: Comment? = nil) {
        self.id = id
        self.type = type
        self.reason = reason
        self.reportDescription = description
        self.reporter = reporter
        self.reportedUser = reportedUser
        self.response = response
        self.comment = comment
        self.status = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = SyncStatus.synced.rawValue
    }
}

// MARK: - SyncableModel Conformance
extension Report: SyncableModel {
    static var collectionPath: String { "reports" }
    
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "type": type.rawValue,
            "reason": reason.rawValue,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "syncStatus": syncStatus
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        if let reportDescription = reportDescription {
            data["reportDescription"] = reportDescription
        }
        if let reporter = reporter {
            data["reporterId"] = reporter.id
        }
        if let reportedUser = reportedUser {
            data["reportedUserId"] = reportedUser.id
        }
        if let response = response {
            data["responseId"] = response.id
        }
        if let comment = comment {
            data["commentId"] = comment.id
        }
        if let moderatorNotes = moderatorNotes {
            data["moderatorNotes"] = moderatorNotes
        }
        if let moderatedBy = moderatedBy {
            data["moderatedBy"] = moderatedBy
        }
        if let moderatedAt = moderatedAt {
            data["moderatedAt"] = Timestamp(date: moderatedAt)
        }
        if let actionTaken = actionTaken {
            data["actionTaken"] = actionTaken.rawValue
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], id: String) throws -> Report {
        guard let typeRaw = data["type"] as? String,
              let type = ReportType(rawValue: typeRaw),
              let reasonRaw = data["reason"] as? String,
              let reason = ReportReason(rawValue: reasonRaw),
              let statusRaw = data["status"] as? String,
              let status = Status(rawValue: statusRaw),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw SyncError.invalidData("Missing required fields for Report")
        }
        
        let report = Report(id: id,
                          type: type,
                          reason: reason,
                          description: data["reportDescription"] as? String,
                          reporter: nil,  // These will be populated by the sync service
                          reportedUser: nil,
                          response: nil,
                          comment: nil)
        
        report.status = status
        report.createdAt = createdAtTimestamp.dateValue()
        report.updatedAt = updatedAtTimestamp.dateValue()
        report.syncStatus = data["syncStatus"] as? String ?? SyncStatus.synced.rawValue
        
        if let lastSyncedAtTimestamp = data["lastSyncedAt"] as? Timestamp {
            report.lastSyncedAt = lastSyncedAtTimestamp.dateValue()
        }
        
        if let moderatorNotes = data["moderatorNotes"] as? String {
            report.moderatorNotes = moderatorNotes
        }
        
        if let moderatedBy = data["moderatedBy"] as? String {
            report.moderatedBy = moderatedBy
        }
        
        if let moderatedAtTimestamp = data["moderatedAt"] as? Timestamp {
            report.moderatedAt = moderatedAtTimestamp.dateValue()
        }
        
        if let actionTakenRaw = data["actionTaken"] as? String,
           let actionTaken = ModeratorAction(rawValue: actionTakenRaw) {
            report.actionTaken = actionTaken
        }
        
        return report
    }
    
    func validate() throws {
        if id.isEmpty {
            throw SyncError.invalidData("Report ID cannot be empty")
        }
    }
    
    func hasConflictsWith(_ other: Report) -> Bool {
        return other.updatedAt > self.lastSyncedAt ?? .distantPast
    }
    
    func mergeChanges(from other: Report) throws -> Report {
        // Use the most recent version
        if other.updatedAt > self.updatedAt {
            self.type = other.type
            self.reason = other.reason
            self.reportDescription = other.reportDescription
            self.status = other.status
            self.reporter = other.reporter
            self.reportedUser = other.reportedUser
            self.response = other.response
            self.comment = other.comment
            self.moderatorNotes = other.moderatorNotes
            self.moderatedBy = other.moderatedBy
            self.moderatedAt = other.moderatedAt
            self.actionTaken = other.actionTaken
        }
        
        self.syncStatus = SyncStatus.pendingUpload.rawValue
        self.lastSyncedAt = Date()
        self.updatedAt = Date()
        
        return self
    }
}

// MARK: - Enums
extension Report {
    enum ReportType: String, Codable {
        case user
        case video
        case comment
        case prompt
        case technical
    }
    
    enum ReportReason: String, Codable {
        case spam
        case harassment
        case inappropriateContent
        case hateSpeech
        case violence
        case copyright
        case impersonation
        case selfHarm
        case misinformation
        case other
    }
    
    enum Status: String, Codable {
        case pending
        case inReview
        case resolved
        case dismissed
        case escalated
    }
    
    enum ModeratorAction: String, Codable {
        case warning
        case contentRemoved
        case temporaryBan
        case permanentBan
        case noAction
    }
} 