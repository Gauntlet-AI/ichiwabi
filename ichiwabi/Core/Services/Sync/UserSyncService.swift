import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class UserSyncService: BaseSyncService<User> {
    private let auth = Auth.auth()
    
    override init(modelContext: ModelContext) {
        print("🔍 Initializing UserSyncService")
        print("🔍 ModelContext: \(modelContext)")
        print("🔍 Container: \(String(describing: modelContext.container))")
        super.init(modelContext: modelContext)
    }
    
    #if DEBUG
    /// Helper method for development to sign in with a test user in the emulator
    @MainActor
    func signInWithTestUser() async throws {
        print("🔍 Attempting to sign in with test user")
        // Test user credentials
        let email = "test@example.com"
        let password = "password123"
        
        do {
            // Try to create the user first
            print("🔍 Attempting to create test user")
            try await Auth.auth().createUser(withEmail: email, password: password)
            print("🔍 Test user created successfully")
        } catch let error as NSError {
            // If the user already exists (error code 17007), that's fine
            if error.code != 17007 {
                print("🔍 Error creating test user: \(error)")
                throw error
            }
            print("🔍 Test user already exists")
        }
        
        do {
            print("🔍 Signing in with test user")
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("🔍 Successfully signed in with test user: \(result.user.uid)")
            
            // Trigger sync after successful sign in
            try await syncCurrentUser()
        } catch {
            print("🔍 Error signing in with test user: \(error)")
            throw error
        }
    }
    #endif
    
    @MainActor
    func verifySwiftDataSetup() async throws {
        print("🔍 Verifying SwiftData setup")
        print("🔍 Current thread: Main thread")
        
        // Since context is not optional in BaseSyncService, we'll just verify it exists
        print("🔍 Context: \(context)")
        
        // Try a simple operation first
        do {
            print("🔍 Attempting simple fetch operation...")
            var descriptor = FetchDescriptor<User>()
            descriptor.fetchLimit = 1
            
            let users = try context.fetch(descriptor)
            print("✅ Fetch successful - found \(users.count) users")
            
            // If we got here, the context is working
            return
            
        } catch {
            print("❌ Initial fetch failed: \(error)")
            
            // Let's try to understand what's wrong with the context
            print("🔍 Diagnosing context state:")
            print("🔍 - Context class: \(type(of: context))")
            print("🔍 - Has pending changes: \(context.hasChanges)")
            
            // Try to save any pending changes
            do {
                print("🔍 Attempting to save context...")
                try context.save()
                print("✅ Context save successful")
            } catch {
                print("❌ Context save failed: \(error)")
            }
            
            throw SyncError.invalidData("SwiftData context is not ready: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func fetchUser(withId id: String) throws -> User? {
        print("🔍 Fetching user with ID: \(id)")
        print("🔍 Context state:")
        print("🔍 - Context: \(context)")
        print("🔍 - Container: \(context.container)")
        print("🔍 - Schema: \(context.container.schema)")
        
        do {
            print("🔍 Starting fetch operation...")
            let descriptor = FetchDescriptor<User>()
            let users = try context.fetch(descriptor)
            print("🔍 Fetch completed, found \(users.count) users")
            
            let matchingUser = users.first(where: { $0.id == id })
            print("🔍 Matching user found: \(matchingUser != nil)")
            
            return matchingUser
        } catch {
            print("🔍 Fetch failed with error: \(error)")
            throw SyncError.invalidData("Failed to fetch user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User-specific Sync Operations
    
    @MainActor
    func syncCurrentUser() async throws {
        print("\n🔐 ==================== SYNC START ====================")
        print("🔐 Starting syncCurrentUser")

        guard let currentUser = auth.currentUser else {
            print("❌ No current Firebase user - not authenticated")
            print("🔐 ==================== SYNC END ====================\n")
            throw SyncError.unauthorized
        }

        print("✅ Firebase user found: \(currentUser.uid)")
        print("📧 Email: \(currentUser.email ?? "none")")
        print("👤 Display name: \(currentUser.displayName ?? "none")")

        // Verify SwiftData setup first
        print("\n🔍 Starting SwiftData verification...")
        try await verifySwiftDataSetup()
        print("✅ SwiftData verification complete")

        do {
            if let localUser = try fetchUser(withId: currentUser.uid) {
                print("\n📱 Found existing user in SwiftData:")
                print("🆔 User ID: \(localUser.id)")
                print("👤 Username: \(localUser.username)")
                print("🔄 Sync status: \(localUser.syncStatus)")
                print("🖼️ Local avatar URL: \(localUser.avatarURL?.absoluteString ?? "none")")

                let docRef = Firestore.firestore().collection(User.collectionPath).document(currentUser.uid)
                print("\n🔥 Checking Firestore document...")
                let document = try await docRef.getDocument()

                if document.exists, let data = document.data() {
                    print("✅ Found Firestore data")
                    print("📄 Firestore data: \(data)")
                    let firestoreUser = try User.fromFirestoreData(data, id: currentUser.uid)
                    print("🖼️ Firestore avatar URL: \(firestoreUser.avatarURL?.absoluteString ?? "none")")

                    // Merge changes from Firestore
                    print("\n🔄 Merging changes...")
                    let updatedUser = try localUser.mergeChanges(from: firestoreUser)
                    print("🖼️ Merged avatar URL: \(updatedUser.avatarURL?.absoluteString ?? "none")")
                    try await sync(updatedUser)
                } else {
                    print("\n📤 No Firestore data found, using local data")
                    try await sync(localUser)
                }
            } else {
                print("\n🆕 No local user found, creating new user...")
                let newUser = User(
                    id: currentUser.uid,
                    username: currentUser.displayName?.lowercased().replacingOccurrences(of: " ", with: "") ?? currentUser.email?.components(separatedBy: "@").first ?? currentUser.uid,
                    displayName: currentUser.displayName ?? "New User",
                    email: currentUser.email ?? "",
                    isEmailVerified: currentUser.isEmailVerified
                )

                print("\n📝 New user details:")
                print("🆔 ID: \(newUser.id)")
                print("👤 Username: \(newUser.username)")
                print("📛 Display Name: \(newUser.displayName)")
                print("📧 Email: \(newUser.email)")

                context.insert(newUser)
                try context.save()
                try await sync(newUser)
            }
        } catch {
            print("\n❌ Sync error: \(error)")
            throw error
        }
        
        print("🔐 ==================== SYNC END ====================\n")
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
        var username = ""
        
        if let email = authUser.email {
            // Use email prefix, remove special characters
            username = email.split(separator: "@")[0]
                .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
                .lowercased()
        } else if let displayName = authUser.displayName {
            // Use display name, remove spaces and special characters
            username = displayName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
                .lowercased()
        } else {
            username = "user_\(String(authUser.uid.prefix(6)))"
        }
        
        // Ensure minimum length
        if username.count < 3 {
            username = "user_\(username)"
        }
        
        // Add random suffix to help ensure uniqueness
        username = "\(username)_\(String(Int.random(in: 1000...9999)))"
        
        return username
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
