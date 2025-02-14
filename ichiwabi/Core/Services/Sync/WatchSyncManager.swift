import Foundation
import WatchConnectivity
import SwiftData
import FirebaseStorage
import BackgroundTasks

enum WatchSyncError: Error {
    case sessionNotActivated
    case encodingFailed
    case decodingFailed
    case audioTransferFailed(Error)
    case dreamConversionFailed(Error)
    case storageError(Error)
}

@MainActor
final class WatchSyncManager: NSObject, ObservableObject {
    static let shared = WatchSyncManager()
    private let session: WCSession
    private let modelContext: ModelContext
    private let storage = Storage.storage()
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.ichiwabi.watchsync"
    
    @Published var isWatchAppInstalled = false
    @Published var isSessionActive = false
    @Published var lastError: WatchSyncError?
    @Published var isBackgroundSyncEnabled = false
    
    private override init() {
        print("\n📱 Initializing WatchSyncManager")
        self.session = .default
        
        // Initialize SwiftData
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Dream.self, configurations: config)
            print("✅ Created SwiftData ModelContainer")
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContext = container.mainContext
        print("✅ Created ModelContext")
        
        super.init()
        
        // Configure WCSession
        if WCSession.isSupported() {
            print("✅ WatchConnectivity is supported")
            session.delegate = self
            session.activate()
            print("🔄 WCSession activation requested")
        } else {
            print("❌ WatchConnectivity is not supported")
        }
        
        // Register background task
        registerBackgroundTask()
    }
    
    // MARK: - Background Task Management
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                print("❌ Unexpected task type received")
                return
            }
            self?.handleBackgroundTask(refreshTask)
        }
        
        scheduleNextBackgroundTask()
    }
    
    private func scheduleNextBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled next background sync task")
        } catch {
            print("❌ Could not schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        print("\n🔄 Starting background sync task")
        
        // Set up task expiration
        task.expirationHandler = { [weak self] in
            print("⚠️ Background task is about to expire")
            self?.scheduleNextBackgroundTask()
        }
        
        // Perform sync
        Task {
            do {
                if session.activationState == .activated && session.isWatchAppInstalled {
                    // Check for any pending Watch data
                    // This will trigger didReceiveMessageData if there's pending data
                    print("✅ WCSession is active, checking for pending data")
                } else {
                    print("⚠️ WCSession not ready for background sync")
                }
                
                // Schedule next task
                scheduleNextBackgroundTask()
                
                // Mark task complete
                task.setTaskCompleted(success: true)
                print("✅ Background sync task completed")
                
            } catch {
                print("❌ Background sync task failed: \(error)")
                task.setTaskCompleted(success: false)
                scheduleNextBackgroundTask()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable background sync
    func setBackgroundSync(enabled: Bool) {
        isBackgroundSyncEnabled = enabled
        if enabled {
            scheduleNextBackgroundTask()
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        }
    }
    
    /// Trigger a sync when accessing the dream library
    func triggerLibrarySync() {
        print("\n🔄 Library sync triggered")
        
        guard session.activationState == .activated else {
            print("❌ WCSession not activated")
            lastError = .sessionNotActivated
            return
        }
        
        if !session.isWatchAppInstalled {
            print("ℹ️ Watch app not installed, skipping sync")
            return
        }
        
        if !session.isReachable {
            print("ℹ️ Watch not reachable, will sync when available")
            return
        }
        
        // Send a message to the Watch to trigger sync
        Task {
            do {
                try await session.sendMessage(
                    ["action": "sync_request"],
                    replyHandler: { response in
                        print("✅ Watch acknowledged sync request: \(response)")
                    }
                )
                print("✅ Sent sync request to Watch")
            } catch {
                print("❌ Failed to send sync request: \(error)")
                lastError = .encodingFailed
            }
        }
    }
    
    /// Process received dream data from Watch app
    func processDreamData(_ data: Data) async throws {
        print("\n📱 Processing received dream data")
        
        do {
            // Decode the dream data
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let dreamDict = jsonObject as? [String: Any] else {
                throw WatchSyncError.decodingFailed
            }
            
            // Create ISO8601 date formatter
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Extract dream data
            guard let dreamId = UUID(uuidString: dreamDict["dreamId"] as? String ?? ""),
                  let userId = dreamDict["userId"] as? String,
                  let title = dreamDict["title"] as? String,
                  let description = dreamDict["description"] as? String,
                  let dateStr = dreamDict["date"] as? String,
                  let date = dateFormatter.date(from: dateStr),
                  let createdAtStr = dreamDict["createdAt"] as? String,
                  let createdAt = dateFormatter.date(from: createdAtStr),
                  let updatedAtStr = dreamDict["updatedAt"] as? String,
                  let updatedAt = dateFormatter.date(from: updatedAtStr) else {
                throw WatchSyncError.decodingFailed
            }
            
            let localAudioPath = dreamDict["localAudioPath"] as? String
            let transcript = dreamDict["transcript"] as? String
            let videoStyleRaw = dreamDict["videoStyle"] as? String ?? "realistic"
            
            // Create new Dream instance
            let dream = Dream(
                userId: userId,
                title: title,
                description: description,
                date: date,
                dreamDate: date,
                isFromWatch: true
            )
            
            // Set additional properties
            dream.dreamId = dreamId
            dream.createdAt = createdAt
            dream.updatedAt = updatedAt
            dream.transcript = transcript
            dream.localAudioPath = localAudioPath
            dream.videoStyle = DreamVideoStyle(rawValue: videoStyleRaw) ?? .realistic
            
            // Save to SwiftData
            modelContext.insert(dream)
            try modelContext.save()
            print("✅ Dream saved to SwiftData: \(dream.dreamId)")
            
            // Handle audio file if present
            if let audioPath = localAudioPath {
                try await processAudioFile(audioPath, for: dream)
            }
            
        } catch {
            print("❌ Failed to process dream data: \(error)")
            throw WatchSyncError.dreamConversionFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func processAudioFile(_ audioPath: String, for dream: Dream) async throws {
        print("🎵 Processing audio file: \(audioPath)")
        
        do {
            // Get the audio file from temporary directory
            let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(audioPath)
            
            // Upload to Firebase Storage
            let audioRef = storage.reference().child("users/\(dream.userId)/audio/\(dream.dreamId).m4a")
            _ = try await audioRef.putFile(from: audioURL)
            let downloadURL = try await audioRef.downloadURL()
            
            // Update dream with audio URL
            dream.audioURL = downloadURL
            try modelContext.save()
            print("✅ Audio file processed and uploaded: \(downloadURL)")
            
            // Clean up temporary file
            try FileManager.default.removeItem(at: audioURL)
            print("🧹 Cleaned up temporary audio file")
            
        } catch {
            print("❌ Failed to process audio file: \(error)")
            throw WatchSyncError.audioTransferFailed(error)
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSyncManager: WCSessionDelegate {
    func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            print("📱 WCSession became inactive")
            self.isSessionActive = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            print("📱 WCSession deactivated")
            self.isSessionActive = false
            // Reactivate for future interactions
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession activation failed: \(error)")
                self.lastError = .sessionNotActivated
                self.isSessionActive = false
            } else {
                print("✅ WCSession activated with state: \(activationState.rawValue)")
                self.isSessionActive = (activationState == .activated)
                self.isWatchAppInstalled = session.isWatchAppInstalled
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            print("📱 Received message data from Watch")
            do {
                try await processDreamData(messageData)
            } catch {
                print("❌ Failed to process message data: \(error)")
                self.lastError = error as? WatchSyncError ?? .decodingFailed
            }
        }
    }
} 