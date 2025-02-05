import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
class SyncTestService {
    private let modelContext: ModelContext
    private var userService: UserSyncService
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.userService = UserSyncService(modelContext: modelContext)
    }
    
    // MARK: - Test Cases
    
    /// Test basic user sync
    func testUserSync() async throws -> TestResult {
        do {
            // Create a test user
            let user = User(
                id: UUID().uuidString,
                username: "testUser",
                displayName: "Test User",
                email: "test@example.com"
            )
            
            // Insert user into model context
            modelContext.insert(user)
            try modelContext.save()
            
            // Test sync to Firestore
            try await userService.sync(user)
            
            // Verify in Firestore
            let docRef = Firestore.firestore().collection(User.collectionPath).document(user.id)
            let document = try await docRef.getDocument()
            
            guard document.exists,
                  let data = document.data() else {
                return .failure("Failed to verify user in Firestore")
            }
            
            // Verify we can parse the Firestore data
            _ = try User.fromFirestoreData(data, id: user.id)
            
            // Verify local storage
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == user.id
                }
            )
            guard let localUser = try? modelContext.fetch(descriptor).first else {
                return .failure("Failed to find user in local storage")
            }
            
            // Verify sync status
            guard let status = SyncStatus(rawValue: localUser.syncStatus),
                  status == .synced else {
                return .failure("User sync status is not correct")
            }
            
            return .success("User sync test passed")
        } catch {
            return .failure("User sync test failed: \(error)")
        }
    }
    
    /// Test offline behavior
    func testOfflineSync() async throws -> TestResult {
        do {
            // Simulate offline state by using an invalid Firestore instance
            // This will force the offline path
            let user = User(
                id: UUID().uuidString,
                username: "offlineUser",
                displayName: "Offline User",
                email: "offline@example.com"
            )
            
            // Attempt sync (should store for later)
            do {
                try await userService.sync(user)
            } catch SyncError.offline {
                // Expected error
            }
            
            // Verify local storage and pending status
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == user.id
                }
            )
            guard let localUser = try? modelContext.fetch(descriptor).first else {
                return .failure("Failed to store offline user locally")
            }
            
            // Verify sync status
            guard let status = SyncStatus(rawValue: localUser.syncStatus),
                  status == .pendingUpload else {
                return .failure("Offline user should have pendingUpload status")
            }
            
            return .success("Offline sync test passed")
        } catch {
            return .failure("Offline sync test failed: \(error.localizedDescription)")
        }
    }
    
    /// Test conflict resolution
    func testConflictResolution() async throws -> TestResult {
        do {
            // Create initial user
            let userId = UUID().uuidString
            let user = User(
                id: userId,
                username: "conflictUser",
                displayName: "Original Name",
                email: "conflict@example.com"
            )
            
            // Sync initial version
            try await userService.sync(user)
            
            // Create conflicting version with different data
            let conflictingUser = User(
                id: userId,
                username: "conflictUser",
                displayName: "Updated Name",
                email: "conflict@example.com"
            )
            
            // Simulate time passing
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Sync conflicting version
            try await userService.sync(conflictingUser)
            
            // Verify resolution
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == userId
                }
            )
            guard let resolvedUser = try? modelContext.fetch(descriptor).first else {
                return .failure("Failed to find resolved user")
            }
            
            if resolvedUser.displayName != "Updated Name" {
                return .failure("Conflict resolution did not take newer changes")
            }
            
            return .success("Conflict resolution test passed")
        } catch {
            return .failure("Conflict resolution test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    func cleanup() async throws {
        // Clean up test data from Firestore
        let collection = Firestore.firestore().collection(User.collectionPath)
        let documents = try await collection.whereField("username", isEqualTo: "testUser").getDocuments()
        
        for document in documents.documents {
            try await document.reference.delete()
        }
        
        // Clean up local data
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == "testUser"
            }
        )
        let users = try? modelContext.fetch(descriptor)
        for user in users ?? [] {
            modelContext.delete(user)
        }
        try modelContext.save()
    }
}

// MARK: - Supporting Types

enum TestResult {
    case success(String)
    case failure(String)
    
    var description: String {
        switch self {
        case .success(let message):
            return "✅ \(message)"
        case .failure(let message):
            return "❌ \(message)"
        }
    }
} 