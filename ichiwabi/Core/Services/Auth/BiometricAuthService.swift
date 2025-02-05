import Foundation
import LocalAuthentication

enum BiometricType {
    case none
    case touchID
    case faceID
    
    var description: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case cancelled
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication methods are enrolled"
        case .cancelled:
            return "Authentication was cancelled"
        case .failed(let message):
            return message
        }
    }
}

@Observable
final class BiometricAuthService {
    private let context = LAContext()
    private let defaults = UserDefaults.standard
    private let biometricEnabledKey = "biometricAuthEnabled"
    
    var isBiometricEnabled: Bool {
        get { defaults.bool(forKey: biometricEnabledKey) }
        set { defaults.set(newValue, forKey: biometricEnabledKey) }
    }
    
    var biometricType: BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            return .none
        }
    }
    
    func authenticate() async throws {
        guard isBiometricEnabled else { return }
        
        let reason = "Unlock ichiwabi"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if !success {
                throw BiometricError.failed("Authentication failed")
            }
        } catch let error as LAError {
            switch error.code {
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryNotEnrolled:
                throw BiometricError.notEnrolled
            case .userCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
    
    func checkBiometricAvailability() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
} 