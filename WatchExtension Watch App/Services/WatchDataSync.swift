import Foundation
import WatchConnectivity
import SwiftData

enum WatchSyncError: Error {
    case sessionNotActivated
    case sessionNotReachable
    case transferFailed(Error)
    case audioUploadFailed(Error)
    case encodingFailed
    case decodingFailed
}

@MainActor
final class WatchDataSync: NSObject, ObservableObject {
    static let shared = WatchDataSync()
    private let session: WCSession
    private let modelContext: ModelContext
    
    @Published var isReachable = false
    @Published var isTransferring = false
    @Published var lastError: WatchSyncError?
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    
    private override init() {
        print("\n🔄 Initializing WatchDataSync singleton")
        self.session = .default
        
        // Create a temporary context for initialization
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: WatchDream.self, configurations: config)
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
    }
    
    // MARK: - Public Methods
    
    /// Sync a dream recording to the iPhone and remove it from local storage after successful sync
    func syncDream(_ dream: WatchDream) async throws {
        print("\n🔄 Starting syncDream() for: \(dream.dreamId)")
        
        guard session.activationState == .activated else {
            print("❌ WCSession not activated")
            throw WatchSyncError.sessionNotActivated
        }
        
        guard session.isReachable else {
            print("❌ iPhone not reachable")
            dream.watchSyncError = .phoneNotReachable
            try modelContext.save()
            throw WatchSyncError.sessionNotReachable
        }
        
        print("✅ WCSession is activated and reachable")
        
        // Update status
        dream.watchSyncStatus = .uploading
        try modelContext.save()
        print("📝 Updated dream status to uploading")
        
        do {
            // First, upload the audio file if it exists
            if let audioPath = dream.localAudioPath {
                print("🎵 Found audio file to upload: \(audioPath)")
                let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(audioPath)
                try await uploadAudioFile(audioURL, for: dream)
                print("✅ Successfully uploaded audio file")
            } else {
                print("ℹ️ No audio file to upload")
            }
            
            // Then send the dream data
            print("📤 Sending dream data...")
            try await sendDreamData(dream)
            print("✅ Successfully sent dream data")
            
            // Remove the dream from local storage after successful sync
            modelContext.delete(dream)
            try modelContext.save()
            print("✅ Removed dream from local storage")
            
        } catch {
            print("❌ Sync failed with error: \(error)")
            dream.watchSyncStatus = .failed
            dream.watchSyncError = .transferFailed
            try modelContext.save()
            throw WatchSyncError.transferFailed(error)
        }
        print("🔄 Finished syncDream()\n")
    }
    
    // MARK: - Private Methods
    
    private func uploadAudioFile(_ url: URL, for dream: WatchDream) async throws {
        print("📤 Starting audio file upload for dream: \(dream.dreamId)")
        
        var timerRef: Timer?
        var progress: Double = 0
        
        func updateProgress() {
            progress += 0.1
            if progress >= 1.0 {
                timerRef?.invalidate()
                timerRef = nil
            }
            dream.syncProgress = progress
            try? modelContext.save()
            print("📊 Upload progress: \(Int(progress * 100))%")
        }
        
        // Start the timer after defining updateProgress
        let timer = Timer(timeInterval: 0.5, repeats: true, block: { _ in
            updateProgress()
        })
        timerRef = timer
        RunLoop.main.add(timer, forMode: .common)
        
        // Show initial progress
        updateProgress()
        
        do {
            let fileData = try Data(contentsOf: url)
            try await sendDreamData(dream)
            print("✅ Successfully uploaded audio file for dream: \(dream.dreamId)")
            timerRef?.invalidate()
        } catch {
            print("❌ Sync failed with error: \(error)")
            dream.watchSyncStatus = .failed
            dream.watchSyncError = .transferFailed
            try modelContext.save()
            timerRef?.invalidate()
            throw WatchSyncError.transferFailed(error)
        }
    }
    
    private func sendDreamData(_ dream: WatchDream) async throws {
        print("📤 Preparing dream data for transfer")
        
        // Create ISO8601 date formatter
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Create a dictionary with essential dream data
        let dreamData: [String: Any] = [
            "dreamId": dream.dreamId.uuidString,
            "userId": dream.userId,
            "title": dream.title,
            "description": dream.dreamDescription,
            "date": dateFormatter.string(from: dream.date),
            "createdAt": dateFormatter.string(from: dream.createdAt),
            "updatedAt": dateFormatter.string(from: dream.updatedAt),
            "localAudioPath": dream.localAudioPath ?? "",
            "transcript": dream.transcript ?? "",
            "videoStyle": dream.videoStyle?.rawValue ?? "realistic"
        ]
        print("📦 Dream data prepared: \(dreamData)")
        
        let jsonData = try JSONSerialization.data(withJSONObject: dreamData)
        print("✅ JSON serialization successful")
        
        try await session.sendMessageData(jsonData, replyHandler: nil)
        print("✅ Message data sent successfully")
    }
}

// MARK: - WCSessionDelegate
extension WatchDataSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            
            if let error = error {
                self.lastError = .sessionNotActivated
                print("❌ WCSession activation failed: \(error)")
                print("❌ Error details:")
                print("❌ - Description: \(error.localizedDescription)")
                let nsError = error as NSError
                print("❌ - Domain: \(nsError.domain)")
                print("❌ - Code: \(nsError.code)")
                print("❌ - User Info: \(nsError.userInfo)")
            } else {
                print("✅ WCSession activated with state: \(activationState.rawValue)")
                self.isReachable = session.isReachable
                print("📱 iPhone reachable: \(session.isReachable)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            print("\n📱 iPhone reachability changed")
            print("📱 New reachability state: \(session.isReachable)")
            self.isReachable = session.isReachable
            
            if !session.isReachable {
                print("📱 iPhone is no longer reachable")
            }
        }
    }
    
    // Required by WCSessionDelegate but not used for watchOS
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 Received message from iPhone: \(message)")
    }
} 
