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
    case notEnabled
    
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
        case .notEnabled:
            return "Biometric authentication is not enabled"
        }
    }
}

@Observable
final class BiometricAuthService {
    private let context = LAContext()
    private let defaults = UserDefaults.standard
    private let biometricEnabledKey = "biometricAuthEnabled"
    
    init() {
        print("🔐 Initializing BiometricAuthService")
        print("🔐 Checking biometric availability...")
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        print("🔐 Available: \(available)")
        if let error = error {
            print("🔐 Error: \(error.localizedDescription) (Code: \(error.code))")
        }
        print("🔐 Biometry type: \(context.biometryType.rawValue)")
    }
    
    var isBiometricEnabled: Bool {
        get { defaults.bool(forKey: biometricEnabledKey) }
        set { 
            print("🔐 Setting biometric enabled to: \(newValue)")
            defaults.set(newValue, forKey: biometricEnabledKey)
            // Only reset context when enabling
            if newValue {
                context.invalidate()
            }
        }
    }
    
    var biometricType: BiometricType {
        print("🔐 Getting biometric type...")
        let type = context.biometryType
        print("🔐 Raw biometry type: \(type.rawValue)")
        
        switch type {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:  // Added in iOS 17 for Vision Pro
            print("🔐 Optic ID detected, treating as FaceID")
            return .faceID
        @unknown default:
            print("🔐 Unknown biometry type detected: \(type.rawValue), defaulting to none")
            return .none
        }
    }
    
    func authenticate() async throws {
        print("🔐 Starting authentication...")
        guard isBiometricEnabled else {
            print("🔐 Error: Biometric not enabled")
            throw BiometricError.notEnabled
        }
        
        try await authenticateWithoutStateCheck()
    }
    
    func authenticateForSetup() async throws {
        print("🔐 Starting authentication for setup...")
        
        // First check if biometrics is available
        guard checkBiometricAvailability() else {
            print("🔐 Error: Biometrics not available during setup")
            throw BiometricError.notAvailable
        }
        
        try await authenticateWithoutStateCheck()
    }
    
    private func authenticateWithoutStateCheck() async throws {
        // Create a fresh context for each authentication attempt
        let freshContext = LAContext()
        var error: NSError?
        
        guard freshContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("🔐 Cannot evaluate policy")
            if let error = error {
                print("🔐 Policy error: \(error.localizedDescription) (Code: \(error.code))")
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw BiometricError.notAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw BiometricError.notEnrolled
                default:
                    throw BiometricError.failed(error.localizedDescription)
                }
            }
            throw BiometricError.notAvailable
        }
        
        let reason = "Unlock yorutabi"
        print("🔐 Requesting authentication with reason: \(reason)")
        
        do {
            let success = try await freshContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            print("🔐 Authentication result: \(success)")
            if !success {
                throw BiometricError.failed("Authentication failed")
            }
        } catch let error as LAError {
            print("🔐 LAError during authentication: \(error.localizedDescription) (Code: \(error.code))")
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                throw BiometricError.cancelled
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryNotEnrolled:
                throw BiometricError.notEnrolled
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
    
    func checkBiometricAvailability() -> Bool {
        print("🔐 Checking biometric availability...")
        // Use a fresh context for availability check
        let freshContext = LAContext()
        var error: NSError?
        let canEvaluate = freshContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        print("🔐 Can evaluate: \(canEvaluate)")
        if let error = error {
            print("🔐 Error checking availability: \(error.localizedDescription) (Code: \(error.code))")
        }
        return canEvaluate
    }
    
    func resetSettings() {
        print("🔐 Resetting biometric settings")
        isBiometricEnabled = false
        context.invalidate()
    }
} 
