import Foundation
import FirebaseCore
import FirebaseStorage

/// This class handles Firebase configuration and provides shared Storage instance
class FirebaseConfiguration {
    static let shared = FirebaseConfiguration()
    let storage: Storage
    
    private init() {
        // Configure Firebase if it hasn't been configured yet
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured for Watch App")
        }
        
        // Initialize Storage instance
        storage = Storage.storage()
        print("📱 Watch App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📦 Storage instance initialized")
    }
    
    // Helper method to verify Firebase is working
    func verifyConfiguration() {
        print("🔥 Verifying Firebase configuration...")
        print("📦 Storage instance: \(storage)")
    }
} 
