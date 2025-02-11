import Foundation
import FirebaseAuth

final class AuthService {
    static let shared = AuthService()
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private init() {}
    
    func signInAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("👤 Signed in anonymously with user ID: \(result.user.uid)")
        } catch {
            print("❌ Anonymous sign in failed: \(error)")
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            print("👤 Signed out successfully")
        } catch {
            print("❌ Sign out failed: \(error)")
            throw error
        }
    }
} 