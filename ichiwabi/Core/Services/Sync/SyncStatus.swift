import Foundation

public enum SyncStatus: String, Codable {
    case synced = "synced"
    case pendingUpload = "pendingUpload"
    case pendingDelete = "pendingDelete"
    case error = "error"
} 