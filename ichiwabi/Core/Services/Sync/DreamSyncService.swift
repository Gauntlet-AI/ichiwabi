import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseCore

enum DreamSyncError: LocalizedError {
    case networkError
    case noNetwork
    case firestoreError(Error)
    case modelError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred while syncing dreams"
        case .noNetwork:
            return "No network connection available"
        case .firestoreError(let error):
            return "Firestore error: \(error.localizedDescription)"
        case .modelError(let error):
            return "Model error: \(error.localizedDescription)"
        }
    }
}

@MainActor
class DreamSyncService {
    private let modelContext: ModelContext
    private let db: Firestore
    private let videoService = VideoUploadService()
    
    init(modelContext: ModelContext) {
        print("\n🔄 ==================== DREAM SYNC SERVICE INIT ====================")
        print("🔄 Initializing DreamSyncService")
        print("🔄 ModelContext: \(modelContext)")
        print("🔄 Container: \(String(describing: modelContext.container))")
        print("🔄 Schema: \(String(describing: modelContext.container.schema))")
        print("🔄 ==================== DREAM SYNC SERVICE INIT END ====================\n")
        
        self.modelContext = modelContext
        self.db = Firestore.firestore()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        self.db.settings = settings
    }
    
    private func fetchLocalDreams(userId: String? = nil) throws -> [Dream] {
        print("\n🔄 ==================== FETCH LOCAL DREAMS ====================")
        print("🔄 Starting fetch for userId: \(userId ?? "all")")
        print("🔄 ModelContext state:")
        print("🔄 - Has changes: \(modelContext.hasChanges)")
        print("🔄 - Container: \(String(describing: modelContext.container))")
        
        do {
            var descriptor = FetchDescriptor<Dream>()
            if let userId = userId {
                print("🔄 Adding user filter: \(userId)")
                descriptor.predicate = #Predicate<Dream> { dream in
                    dream.userId == userId
                }
            }
            
            print("🔄 Executing fetch...")
            let results = try modelContext.fetch(descriptor)
            print("✅ Fetch successful - found \(results.count) dreams")
            print("🔄 ==================== FETCH END ====================\n")
            return results
        } catch {
            print("❌ Fetch failed with error: \(error)")
            print("❌ Error details:")
            print("❌ - Description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ - Domain: \(nsError.domain)")
                print("❌ - Code: \(nsError.code)")
                print("❌ - User Info: \(nsError.userInfo)")
            }
            print("🔄 ==================== FETCH END ====================\n")
            throw error
        }
    }
    
    /// Syncs dream metadata (titles, descriptions, etc.) without downloading videos
    func syncDreamMetadata(for userId: String) async throws {
        print("🔄 Starting metadata sync for user: \(userId)")
        
        // Fetch from Firestore first
        print("🔄 Fetching from Firestore")
        let dreamsRef = db.collection("dreams")
            .whereField("userId", isEqualTo: userId)
        
        do {
            let snapshot = try await dreamsRef.getDocuments()
            print("✅ Fetched \(snapshot.documents.count) dreams from Firestore")
            
            // Get existing dreams from local storage
            let localDreams = try fetchLocalDreams(userId: userId)
            print("📱 Found \(localDreams.count) dreams in local storage")
            
            // Process each dream from Firestore
            for document in snapshot.documents {
                print("🔄 Processing dream: \(document.documentID)")
                
                guard let dream = Dream.fromFirestore(document.data()) else {
                    print("⚠️ Failed to parse dream: \(document.documentID)")
                    continue
                }
                
                // Look for existing dream
                if let existingDream = localDreams.first(where: { 
                    $0.dreamId.uuidString == dream.dreamId.uuidString 
                }) {
                    print("🔄 Updating existing dream: \(existingDream.dreamId)")
                    // Update metadata only
                    existingDream.title = dream.title
                    existingDream.dreamDescription = dream.dreamDescription
                    existingDream.transcript = dream.transcript
                    existingDream.dreamDate = dream.dreamDate
                    existingDream.updatedAt = dream.updatedAt
                    // Keep existing video path if we have it
                    if existingDream.localVideoPath == nil {
                        existingDream.videoURL = dream.videoURL
                    }
                } else {
                    print("🔄 Creating new dream: \(dream.dreamId)")
                    modelContext.insert(dream)
                }
            }
            
            print("🔄 Saving changes to SwiftData")
            try modelContext.save()
            print("✅ Metadata sync completed successfully")
            
        } catch let error as NSError {
            print("❌ Sync error: \(error)")
            print("❌ Error domain: \(error.domain)")
            print("❌ Error code: \(error.code)")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Error user info: \(error.userInfo)")
            
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    throw DreamSyncError.noNetwork
                default:
                    throw DreamSyncError.networkError
                }
            }
            
            throw DreamSyncError.firestoreError(error)
        }
    }
    
    /// Loads the video for a specific dream when needed
    func loadVideoForDream(_ dream: Dream) async throws {
        // Check if we have both a local path and the file actually exists
        if let localPath = dream.localVideoPath,
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Construct full path including dreams/userId subdirectories
            let fullPath = "dreams/\(dream.userId)/\(localPath)"
            let localURL = documentsPath.appendingPathComponent(fullPath)
            print("📼 Full local path: \(localURL.path)")
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("📼 Video already loaded locally at path: \(fullPath)")
                return
            } else {
                print("⚠️ Local path exists but file is missing, will re-download")
            }
        }
        
        print("📼 Loading video for dream: \(dream.dreamId)")
        
        let videoURL = dream.videoURL
        print("📥 Starting video download from: \(videoURL)")
        
        do {
            let localURL = try await videoService.downloadVideo(
                from: videoURL,
                userId: dream.userId
            )
            print("📥 Local path will be: \(localURL.lastPathComponent)")
            // Store just the filename, not the full path
            dream.localVideoPath = localURL.lastPathComponent
            try modelContext.save()
            print("✅ Video downloaded and saved locally")
            
            // Verify the file exists
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: localURL.path) {
                print("✅ Verified file exists at: \(localURL.path)")
            } else {
                print("⚠️ File not found at expected path: \(localURL.path)")
                throw DreamSyncError.modelError(NSError(domain: "DreamSync", code: -2, userInfo: [NSLocalizedDescriptionKey: "File not found after download"]))
            }
        } catch {
            print("⚠️ Failed to download video: \(error)")
            throw error
        }
    }
    
    /// Checks if a dream has its video loaded locally
    func isDreamVideoLoaded(_ dream: Dream) -> Bool {
        guard let localPath = dream.localVideoPath else { return false }
        
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let videoURL = documentsPath.appendingPathComponent(localPath)
        return fileManager.fileExists(atPath: videoURL.path)
    }
    
    /// Cleans up local video files that haven't been accessed recently
    func cleanupUnusedVideos() async throws {
        print("🧹 Starting video cleanup")
        
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Get all dreams with local videos
        let localDreams = try fetchLocalDreams()
        let activePaths = Set(localDreams.compactMap { $0.localVideoPath })
        print("📱 Found \(localDreams.count) dreams with \(activePaths.count) active video paths")
        
        // Check the dreams directory
        let dreamsPath = documentsPath.appendingPathComponent("dreams")
        guard let contents = try? fileManager.contentsOfDirectory(at: dreamsPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        // Remove files that aren't referenced by any dream
        for url in contents {
            let filename = url.lastPathComponent
            if !activePaths.contains(filename) {
                try? fileManager.removeItem(at: url)
                print("🗑️ Removed unused video: \(filename)")
            }
        }
        
        print("✅ Video cleanup completed")
    }
} 
