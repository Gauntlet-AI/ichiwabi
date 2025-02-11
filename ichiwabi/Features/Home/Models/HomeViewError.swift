import Foundation

enum HomeViewError: LocalizedError, Equatable {
    case signOutFailed(String)
    case serviceNotInitialized
    case loadFailed(Error)
    case streakCalculationFailed(Error)
    case other(String)
    
    var errorDescription: String? {
        switch self {
        case .signOutFailed(let message):
            return "Failed to sign out: \(message)"
        case .serviceNotInitialized:
            return "Dream service not initialized"
        case .loadFailed(let error):
            return "Failed to load dreams: \(error.localizedDescription)"
        case .streakCalculationFailed(let error):
            return "Failed to calculate streak: \(error.localizedDescription)"
        case .other(let message):
            return message
        }
    }
    
    static func == (lhs: HomeViewError, rhs: HomeViewError) -> Bool {
        switch (lhs, rhs) {
        case (.signOutFailed(let lhsMsg), .signOutFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.serviceNotInitialized, .serviceNotInitialized):
            return true
        case (.loadFailed, .loadFailed):
            return true
        case (.streakCalculationFailed, .streakCalculationFailed):
            return true
        case (.other(let lhsMsg), .other(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
} 