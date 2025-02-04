import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class UserSyncService: BaseSyncService<User> {
    private let auth = Auth.auth()
    
    override init(modelContext: ModelContext) {
        super.init(modelContext: modelContext)
    }
    
    private func fetchUser(withId id: String) throws -> User? {
        try context.fetch(FetchDescriptor<User>()).first { user in
            user.id == id
        }
    }
    
    // MARK: - User-specific Sync Operations
    
    /// Sync current user's data
    func syncCurrentUser() async throws {
        guard let currentUser = auth.currentUser else {
            throw SyncError.unauthorized
        }
        
        // First try to find existing user in SwiftData
        if let localUser = try? fetchUser(withId: currentUser.uid) {
            do {
                let docRef = Firestore.firestore().collection(User.collectionPath).document(currentUser.uid)
                let document = try await docRef.getDocument()
                
                if document.exists, let data = document.data() {
                    // Update existing user with Firestore data
                    let firestoreUser = try User.fromFirestoreData(data, id: currentUser.uid)
                    try await localUser.mergeChanges(from: firestoreUser)
                    try await sync(localUser)
                } else {
                    // No Firestore data, push local user to Firestore
                    try await sync(localUser)
                }
            } catch {
                print("Error syncing with Firestore: \(error)")
                // Keep using local user data
            }
            return
        }
        
        // No local user, try to get from Firestore
        do {
            let docRef = Firestore.firestore().collection(User.collectionPath).document(currentUser.uid)
            let document = try await docRef.getDocument()
            
            if document.exists, let data = document.data() {
                let user = try User.fromFirestoreData(data, id: currentUser.uid)
                try await sync(user)
            } else {
                // No user anywhere, create new
                try await createNewUser(from: currentUser)
            }
        } catch {
            // If all else fails, create new user
            print("Error fetching from Firestore: \(error)")
            try await createNewUser(from: currentUser)
        }
    }
    
    /// Create a new user from Firebase Auth user
    private func createNewUser(from authUser: FirebaseAuth.User) async throws {
        let user = User(
            id: authUser.uid,
            username: generateDefaultUsername(from: authUser),
            displayName: authUser.displayName ?? "User",
            email: authUser.email ?? "",
            isEmailVerified: authUser.isEmailVerified
        )
        
        // Ensure username uniqueness
        try await ensureUniqueUsername(for: user)
        
        // Sync to Firestore
        try await sync(user)
    }
    
    /// Generate a default username from email or display name
    private func generateDefaultUsername(from authUser: FirebaseAuth.User) -> String {
        if let email = authUser.email {
            // Use email prefix, remove special characters
            let username = email.split(separator: "@")[0]
                .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
            return username
        } else if let displayName = authUser.displayName {
            // Use display name, remove spaces and special characters
            return displayName.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        } else {
            return "user_\(String(authUser.uid.prefix(6)))"
        }
    }
    
    /// Ensure username is unique by checking Firestore
    private func ensureUniqueUsername(for user: User) async throws {
        let query = Firestore.firestore()
            .collection(User.collectionPath)
            .whereField("username", isEqualTo: user.username)
        
        let snapshot = try await query.getDocuments()
        if !snapshot.documents.isEmpty {
            // Username exists, append random numbers
            user.username = "\(user.username)_\(String(Int.random(in: 1000...9999)))"
            // Recursively check again
            try await ensureUniqueUsername(for: user)
        }
    }
    
    /// Update user profile completion status
    func updateProfileCompletion(isComplete: Bool) async throws {
        guard let currentUser = auth.currentUser else {
            throw SyncError.unauthorized
        }
        
        guard let user = try? fetchUser(withId: currentUser.uid) else {
            throw SyncError.notFound
        }
        
        user.isProfileComplete = isComplete
        user.updatedAt = Date()
        
        try await sync(user)
    }
    
    /// Update terms acceptance
    func updateTermsAcceptance(accepted: Bool) async throws {
        guard let currentUser = auth.currentUser else {
            throw SyncError.unauthorized
        }
        
        guard let user = try? fetchUser(withId: currentUser.uid) else {
            throw SyncError.notFound
        }
        
        user.hasAcceptedTerms = accepted
        user.updatedAt = Date()
        
        try await sync(user)
    }
    
    /// Sync user's following list
    func syncFollowing(for userId: String) async throws {
        let followingRef = Firestore.firestore()
            .collection(User.collectionPath)
            .document(userId)
            .collection("relationships")
            .whereField("type", isEqualTo: "following")
        
        let snapshot = try await followingRef.getDocuments()
        let followingIds = snapshot.documents.map { $0.documentID }
        let followingUsers = try await fetchUsers(withIds: followingIds)
        
        // Sync each following user individually
        for following in followingUsers {
            try await sync(following)
        }
    }
    
    /// Sync user's followers
    func syncFollowers(for userId: String) async throws {
        let followersRef = Firestore.firestore()
            .collection(User.collectionPath)
            .document(userId)
            .collection("relationships")
            .whereField("type", isEqualTo: "follower")
        
        let snapshot = try await followersRef.getDocuments()
        
        let followerIds = snapshot.documents.map { $0.documentID }
        let followerUsers = try await fetchUsers(withIds: followerIds)
        
        // Sync each follower individually
        for follower in followerUsers {
            try await sync(follower)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchUsers(withIds ids: [String]) async throws -> [User] {
        var users: [User] = []
        
        for id in ids {
            let docRef = Firestore.firestore().collection(User.collectionPath).document(id)
            let document = try await docRef.getDocument()
            
            if let data = document.data() {
                if let user = try? User.fromFirestoreData(data, id: id) {
                    users.append(user)
                }
            }
        }
        
        return users
    }
    
    // MARK: - Real-time Updates
    
    /// Observe changes to the current user's data
    func observeCurrentUser(completion: @escaping (Result<User, Error>) -> Void) -> ListenerRegistration? {
        guard let currentUserId = auth.currentUser?.uid else {
            completion(.failure(SyncError.unauthorized))
            return nil
        }
        
        return Firestore.firestore()
            .collection(User.collectionPath)
            .document(currentUserId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot,
                      let data = snapshot.data() else {
                    completion(.failure(SyncError.invalidData("No snapshot available")))
                    return
                }
                
                do {
                    let user = try User.fromFirestoreData(data, id: currentUserId)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            }
    }
} 