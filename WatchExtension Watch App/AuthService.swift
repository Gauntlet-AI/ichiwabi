import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published private(set) var currentUserId: String?
    
    private init() {
        // Add auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                print("🔐 Watch Auth State Changed: User signed in with ID: \(user.uid)")
                self?.currentUserId = user.uid
            } else {
                print("🔐 Watch Auth State Changed: User signed out")
                self?.currentUserId = nil
            }
        }
        
        // Initialize currentUserId
        currentUserId = Auth.auth().currentUser?.uid
    }
    
    func signInAnonymously() async throws {
        print("🔑 Watch attempting anonymous sign in...")
        let result = try await Auth.auth().signInAnonymously()
        print("✅ Watch successfully signed in anonymously with user ID: \(result.user.uid)")
        currentUserId = result.user.uid
    }
    
    func signOut() throws {
        print("🔑 Watch attempting sign out...")
        try Auth.auth().signOut()
        print("✅ Watch successfully signed out")
    }
} 