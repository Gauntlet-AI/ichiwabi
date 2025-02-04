import Foundation

enum SyncError: LocalizedError {
    case unauthorized
    case offline
    case notFound
    case invalidData(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Not authorized"
        case .offline:
            return "No internet connection"
        case .notFound:
            return "Resource not found"
        case .invalidData(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 