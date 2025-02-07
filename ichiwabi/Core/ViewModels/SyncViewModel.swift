import Foundation
import SwiftData
import FirebaseAuth

@MainActor
class SyncViewModel: ObservableObject {
    private let syncService: DreamSyncService
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var isOffline = false
    
    init(modelContext: ModelContext) {
        print("\n🔄 ==================== SYNC VIEW MODEL INIT ====================")
        print("🔄 Initializing SyncViewModel")
        print("🔄 ModelContext description: \(modelContext)")
        print("🔄 ==================== SYNC VIEW MODEL INIT END ====================\n")
        
        self.syncService = DreamSyncService(modelContext: modelContext)
    }
    
    func syncDreams() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            lastSyncError = "No user logged in"
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        isOffline = false
        
        do {
            print("\n🔄 ==================== SYNC START ====================")
            print("🔄 Starting sync for user: \(userId)")
            try await syncService.syncDreamMetadata(for: userId)
            print("✅ Sync completed successfully")
            print("🔄 ==================== SYNC END ====================\n")
        } catch DreamSyncError.noNetwork {
            isOffline = true
            lastSyncError = "Unable to sync - no network connection"
            print("⚠️ No network connection available")
        } catch DreamSyncError.networkError {
            lastSyncError = "Network error occurred while syncing"
            print("❌ Network error during sync")
        } catch let error as NSError {
            lastSyncError = error.localizedDescription
            print("❌ Sync failed with error:")
            print("❌ Domain: \(error.domain)")
            print("❌ Code: \(error.code)")
            print("❌ Description: \(error.localizedDescription)")
            print("❌ User Info: \(error.userInfo)")
        }
        
        isSyncing = false
    }
    
    func cleanupStorage() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            lastSyncError = "No user logged in"
            return
        }
        
        isSyncing = true
        lastSyncError = nil
        
        do {
            try await syncService.cleanupUnusedVideos()
        } catch {
            lastSyncError = error.localizedDescription
            print("❌ Storage cleanup failed: \(error)")
        }
        
        isSyncing = false
    }
} 