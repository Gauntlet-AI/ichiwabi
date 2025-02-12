import SwiftUI
import AVKit
import FirebaseStorage
import SwiftData
import os.log

struct VideoProcessingTestView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var videoProcessingService = VideoProcessingService()
    @State private var isProcessing = false
    @State private var error: Error?
    @State private var processedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var originalDream: Dream?
    @State private var currentStage = "Not started"
    @State private var processingProgress: Double = 0
    
    // Test video URLs - replace with your specific Replicate URL
    private let replicateVideoURL = URL(string: "https://replicate.delivery/xezq/DCWDEm12m364JZG7VsnPbA2Msfe4xob7a03k0sJqiAN2yoOUA/tmpmqopzmrk.mp4")!
    private let dreamId = "E0FDCBEA-4769-4290-86D7-A79D339BFB6A"
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ichiwabi", category: "VideoProcessing")
    
    init() {
        let id = dreamId // Create a local copy
        Self.logger.notice("📱 ==================== VIEW INITIALIZED ====================")
        Self.logger.notice("📱 Dream ID to load: \(id)")
        
        // Force console output
        print("TEST - View Initialized")
        fputs("TEST - View Initialized via fputs\n", stderr)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Video Processing Test")
                    .font(.title)
                    .padding()
                    .onAppear {
                        print("\n📱 ==================== VIEW APPEARED ====================")
                    }
                
                if let originalDream = originalDream {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Dream Details:")
                            .font(.headline)
                        Text("Title: \(originalDream.title)")
                        Text("ID: \(originalDream.dreamId.uuidString)")
                        Text("Video Style: \(originalDream.videoStyle?.rawValue ?? "none")")
                        Text("Original URL: \(originalDream.videoURL.absoluteString)")
                        Text("Local Audio Path: \(originalDream.localAudioPath ?? "none")")
                        if let audioURL = originalDream.audioURL {
                            Text("Audio URL: \(audioURL.absoluteString)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 400)
                        .onAppear {
                            Task {
                                print("\n🔊 ==================== PLAYBACK SETUP ====================")
                                // Configure audio session for playback
                                do {
                                    // Print current audio session configuration
                                    let audioSession = AVAudioSession.sharedInstance()
                                    print("🔊 Current audio session category: \(audioSession.category.rawValue)")
                                    print("🔊 Current audio session mode: \(audioSession.mode.rawValue)")
                                    print("🔊 Is audio session active: \(audioSession.isOtherAudioPlaying)")
                                    
                                    try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                                    print("🔊 Audio session configured for playback")
                                    print("🔊 New audio session category: \(audioSession.category.rawValue)")
                                    
                                    // Check if player item has audio
                                    if let playerItem = player.currentItem {
                                        let asset = playerItem.asset
                                        print("🔊 Asset duration: \(asset.duration.seconds)")
                                        print("🔊 Asset playable: \(asset.isPlayable)")
                                        
                                        let audioTracks = playerItem.asset.tracks(withMediaType: .audio)
                                        print("🔊 Player audio tracks: \(audioTracks.count)")
                                        
                                        for (index, track) in audioTracks.enumerated() {
                                            print("🔊 Audio track \(index):")
                                            print("🔊 - Enabled: \(track.isEnabled)")
                                            // Get format descriptions properly
                                            if let formatDescriptions = try? await track.load(.formatDescriptions) as [CMFormatDescription],
                                               let firstFormat = formatDescriptions.first {
                                                print("🔊 - Format: \(CMFormatDescriptionGetMediaSubType(firstFormat))")
                                                if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(firstFormat) {
                                                    print("🔊 - Sample Rate: \(audioStreamBasicDescription.pointee.mSampleRate)")
                                                    print("🔊 - Channels: \(audioStreamBasicDescription.pointee.mChannelsPerFrame)")
                                                }
                                            }
                                        }
                                        
                                        // Set up audio mixing
                                        player.volume = 1.0
                                        player.isMuted = false
                                        
                                        // Add periodic time observer to monitor playback
                                        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
                                            print("🔊 Playback time: \(time.seconds) seconds")
                                            print("🔊 Current volume: \(player.volume)")
                                            print("🔊 Is muted: \(player.isMuted)")
                                        }
                                        
                                        print("🔊 Player configuration:")
                                        print("🔊 - Volume: \(player.volume)")
                                        print("🔊 - Is muted: \(player.isMuted)")
                                        print("🔊 - Rate: \(player.rate)")
                                        print("🔊 - Status: \(player.status.rawValue)")
                                        
                                        // Add observer for player item status changes
                                        NotificationCenter.default.addObserver(
                                            forName: .AVPlayerItemDidPlayToEndTime,
                                            object: playerItem,
                                            queue: .main
                                        ) { _ in
                                            print("🔊 Video playback completed")
                                            // Loop playback
                                            player.seek(to: .zero)
                                            player.play()
                                        }
                                    } else {
                                        print("⚠️ No player item available")
                                    }
                                } catch {
                                    print("❌ Failed to configure audio session: \(error)")
                                    if let avError = error as? AVError {
                                        print("❌ AVError code: \(avError.code.rawValue)")
                                    }
                                }
                                print("🔊 ==================== END PLAYBACK SETUP ====================\n")
                            }
                            
                            player.play()
                        }
                        .onDisappear {
                            print("🔊 Player disappearing - cleaning up")
                            player.pause()
                            // Clean up audio session
                            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                        }
                }
                
                VStack(spacing: 12) {
                    Text("Current Stage: \(currentStage)")
                        .font(.headline)
                    
                    if isProcessing {
                        ProgressView(value: processingProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 200)
                        Text("\(Int(processingProgress * 100))%")
                            .font(.caption)
                    }
                }
                .padding()
                
                Button(action: {
                    Task {
                        await processTestVideo()
                    }
                }) {
                    Text(isProcessing ? "Processing..." : "Process Test Video")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
                
                if let error = error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error Details:")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                        if let nsError = error as? NSError {
                            Text("Domain: \(nsError.domain)")
                            Text("Code: \(nsError.code)")
                            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                                Text("Underlying Error: \(underlyingError.localizedDescription)")
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
                
                if let url = processedVideoURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Results:")
                            .font(.headline)
                        Text("Final Video URL:")
                            .font(.subheadline)
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
            }
            .padding()
        }
        .task {
            // Load the dream when view appears
            do {
                print("\n📱 ==================== LOADING TEST DREAM ====================")
                let uuid = UUID(uuidString: dreamId)!
                print("📱 Looking for dream with ID: \(uuid)")
                
                let descriptor = FetchDescriptor<Dream>(
                    predicate: #Predicate<Dream> { dream in
                        dream.dreamId == uuid
                    }
                )
                let dreams = try modelContext.fetch(descriptor)
                if let dream = dreams.first {
                    originalDream = dream
                    print("📱 Found dream:")
                    print("📱 - Title: \(dream.title)")
                    print("📱 - ID: \(dream.dreamId)")
                    print("📱 - Video Style: \(dream.videoStyle?.rawValue ?? "none")")
                    print("📱 - Original URL: \(dream.videoURL)")
                    print("📱 ==================== DREAM LOADED ====================\n")
                } else {
                    print("❌ No dream found with ID: \(uuid)")
                    throw TestError.invalidInput("No dream found with ID: \(uuid)")
                }
            } catch {
                print("\n❌ ==================== ERROR LOADING DREAM ====================")
                print("❌ Error: \(error)")
                if let nsError = error as? NSError {
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    print("❌ User Info: \(nsError.userInfo)")
                }
                print("❌ ==================== END ERROR ====================\n")
                self.error = error
            }
        }
    }
    
    private func processTestVideo() async {
        Self.logger.notice("🎬 ==================== STARTING VIDEO PROCESSING TEST ====================")
        isProcessing = true
        error = nil
        processingProgress = 0
        
        do {
            // Validate dream exists
            guard let dream = originalDream else {
                Self.logger.error("❌ Original dream not found")
                throw TestError.invalidInput("Original dream not found")
            }
            
            Self.logger.notice("🎬 Dream Details:")
            Self.logger.notice("🎬 - Dream ID: \(dream.dreamId)")
            Self.logger.notice("🎬 - Title: \(dream.title)")
            Self.logger.notice("🎬 - Audio URL: \(dream.audioURL?.absoluteString ?? "none")")
            Self.logger.notice("🎬 - User ID: \(dream.userId)")
            
            // Download Replicate video
            await updateStatus(stage: "Downloading Replicate video", progress: 0.1)
            Self.logger.notice("\n📥 Downloading Replicate video from: \(replicateVideoURL)")
            
            let (tempURL, response) = try await URLSession.shared.download(from: replicateVideoURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse("Response is not HTTPURLResponse")
            }
            
            print("📥 Download response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw TestError.invalidResponse("HTTP \(httpResponse.statusCode)")
            }
            
            // Move to temporary file
            let temporaryDirectory = FileManager.default.temporaryDirectory
            let downloadedVideoURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            
            try? FileManager.default.removeItem(at: downloadedVideoURL)
            try FileManager.default.moveItem(at: tempURL, to: downloadedVideoURL)
            
            print("📥 Replicate video downloaded to: \(downloadedVideoURL)")
            
            // Download audio from Firebase
            guard let firebaseAudioURL = dream.audioURL else {
                Self.logger.error("❌ No Firebase audio URL available")
                throw TestError.invalidInput("No Firebase audio URL available")
            }
            
            Self.logger.notice("\n🔊 FIREBASE AUDIO - Downloading from: \(firebaseAudioURL.absoluteString)")
            let (audioTempURL, audioResponse) = try await URLSession.shared.download(from: firebaseAudioURL)
            
            guard let audioHttpResponse = audioResponse as? HTTPURLResponse,
                  audioHttpResponse.statusCode == 200 else {
                Self.logger.error("❌ Failed to download audio from Firebase")
                throw TestError.downloadError("Failed to download audio from Firebase")
            }
            
            // Move to a temporary file
            let firebaseAudioTemp = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            try? FileManager.default.removeItem(at: firebaseAudioTemp)
            try FileManager.default.moveItem(at: audioTempURL, to: firebaseAudioTemp)
            
            Self.logger.notice("✅ Successfully downloaded Firebase audio to: \(firebaseAudioTemp.path)")
            
            // Verify the downloaded audio
            let audioAsset = AVAsset(url: firebaseAudioTemp)
            let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
            if audioTracks.isEmpty {
                Self.logger.error("❌ Downloaded Firebase audio file has no audio tracks")
                throw TestError.invalidInput("Firebase audio file has no audio tracks")
            }
            Self.logger.notice("✅ Firebase audio file has \(audioTracks.count) audio tracks")
            
            // Process and upload video
            let processedResult = try await videoProcessingService.processAndUploadVideo(
                videoURL: downloadedVideoURL,
                audioURL: firebaseAudioTemp,
                userId: dream.userId,
                dreamId: "test_\(dream.dreamId.uuidString)",
                style: dream.videoStyle ?? .realistic,
                title: "Test: \(dream.title)"
            )
            Self.logger.notice("✅ processAndUploadVideo completed successfully")
            Self.logger.notice("🎬 Output video URL: \(processedResult.videoURL.absoluteString)")
            Self.logger.notice("🎬 Output audio URL: \(processedResult.audioURL.absoluteString)")

            // Update the dream with the Firebase Storage URLs
            dream.videoURL = processedResult.videoURL
            dream.audioURL = processedResult.audioURL
            dream.localVideoPath = processedResult.localPath
            try modelContext.save()
            Self.logger.notice("✅ Dream updated with new URLs")

            // Download the processed video to verify it
            Self.logger.notice("\n🔍 POST-PROCESS CHECK - Downloading final video to verify...")
            let (finalVideoData, _) = try await URLSession.shared.data(from: processedResult.videoURL)
            let finalVideoTemp = FileManager.default.temporaryDirectory.appendingPathComponent("final_verify.mp4")
            try finalVideoData.write(to: finalVideoTemp)
            Self.logger.notice("🔍 POST-PROCESS CHECK - Final video size: \(finalVideoData.count) bytes")
            
            // Verify final video has audio
            Self.logger.notice("\n🔍 POST-PROCESS CHECK - Verifying final video")
            let finalAsset = AVAsset(url: finalVideoTemp)
            
            // Check video tracks
            let finalVideoTracks = try await finalAsset.loadTracks(withMediaType: .video)
            Self.logger.notice("🔍 POST-PROCESS CHECK - Final video has \(finalVideoTracks.count) video tracks")
            
            // Check audio tracks with more detail
            let finalAudioTracks = try await finalAsset.loadTracks(withMediaType: .audio)
            Self.logger.notice("🔍 POST-PROCESS CHECK - Final video has \(finalAudioTracks.count) audio tracks")
            
            if finalAudioTracks.isEmpty {
                Self.logger.error("❌ POST-PROCESS CHECK - Final video has no audio tracks!")
                // Try to get more info about the asset
                let isPlayable = try await finalAsset.load(.isPlayable)
                let hasProtectedContent = try await finalAsset.load(.hasProtectedContent)
                Self.logger.notice("🔍 Final video properties:")
                Self.logger.notice("- Is Playable: \(isPlayable)")
                Self.logger.notice("- Has Protected Content: \(hasProtectedContent)")
                if let duration = try? await finalAsset.load(.duration) {
                    Self.logger.notice("- Duration: \(duration.seconds) seconds")
                }
            } else {
                Self.logger.notice("✅ POST-PROCESS CHECK - Final video has audio tracks")
                // Get more details about the audio tracks
                for (index, track) in finalAudioTracks.enumerated() {
                    Self.logger.notice("🔍 POST-PROCESS CHECK - Audio track \(index):")
                    Self.logger.notice("- Enabled: \(track.isEnabled)")
                    if let format = try? await track.load(.formatDescriptions) {
                        Self.logger.notice("- Format: \(String(describing: format))")
                    }
                    // Try to get audio specific properties
                    if let formatDescriptions = try? await track.load(.formatDescriptions) as [CMFormatDescription],
                       let firstFormat = formatDescriptions.first,
                       let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(firstFormat) {
                        Self.logger.notice("- Sample Rate: \(basicDescription.pointee.mSampleRate)")
                        Self.logger.notice("- Channels: \(basicDescription.pointee.mChannelsPerFrame)")
                        Self.logger.notice("- Bytes Per Frame: \(basicDescription.pointee.mBytesPerFrame)")
                        Self.logger.notice("- Format ID: \(basicDescription.pointee.mFormatID)")
                    }
                }
            }
            
            await updateStatus(stage: "Completed", progress: 1.0)
            print("\n✅ Video processed successfully")
            print("✅ Final video URL: \(processedResult.videoURL)")
            
            // Force immediate player setup to test audio
            await MainActor.run {
                let playerItem = AVPlayerItem(url: processedResult.videoURL)
                player = AVPlayer(playerItem: playerItem)
                player?.volume = 1.0
                player?.isMuted = false
                
                // Try to force audio playback
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                
                player?.play()
                
                Self.logger.notice("🎬 Immediate player setup complete")
                Self.logger.notice("🎬 Player volume: \(self.player?.volume ?? 0)")
                Self.logger.notice("🎬 Player is muted: \(self.player?.isMuted ?? true)")
            }
            
            // Cleanup
            print("\n🧹 Cleaning up temporary files...")
            try? FileManager.default.removeItem(at: downloadedVideoURL)
            try? FileManager.default.removeItem(at: firebaseAudioTemp)
            print("🧹 Cleanup complete")
            
            print("🎬 ==================== TEST COMPLETED SUCCESSFULLY ====================\n")
            
        } catch {
            print("\n❌ ==================== ERROR PROCESSING VIDEO ====================")
            print("❌ Error: \(error)")
            if let nsError = error as? NSError {
                print("❌ Domain: \(nsError.domain)")
                print("❌ Code: \(nsError.code)")
                print("❌ User Info: \(nsError.userInfo)")
            }
            print("❌ ==================== END ERROR ====================\n")
            
            await MainActor.run {
                self.error = error
                self.currentStage = "Failed"
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    private func updateStatus(stage: String, progress: Double) async {
        await MainActor.run {
            currentStage = stage
            processingProgress = progress
        }
    }
    
    enum TestError: LocalizedError {
        case invalidResponse(String)
        case audioExtractionFailed
        case invalidInput(String)
        case downloadError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse(let details):
                return "Invalid response from server: \(details)"
            case .audioExtractionFailed:
                return "Failed to extract audio from video"
            case .invalidInput(let message):
                return message
            case .downloadError(let message):
                return "Download error: \(message)"
            }
        }
    }
    
    private func extractAudioFromVideo(at videoURL: URL) async throws -> URL? {
        print("\n🔊 ==================== AUDIO EXTRACTION START ====================")
        print("🔊 Source video URL: \(videoURL)")
        
        let temporaryDirectory = FileManager.default.temporaryDirectory
        var audioURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        print("🔊 Target audio URL: \(audioURL)")
        
        // Load the asset
        let asset = AVAsset(url: videoURL)
        
        // Check if asset is playable
        let isPlayable = try await asset.load(.isPlayable)
        print("🔊 Asset is playable: \(isPlayable)")
        
        // Get tracks
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        print("🔊 Number of audio tracks: \(tracks.count)")
        print("🔊 Has audio tracks: \(tracks.count > 0)")
        
        // Get duration
        let duration = try await asset.load(.duration)
        print("🔊 Asset duration: \(duration.seconds) seconds")
        
        // Try to get more details about the audio track if available
        if let audioTrack = tracks.first {
            let format = try await audioTrack.load(.formatDescriptions)
            print("🔊 Audio format descriptions: \(String(describing: format))")
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("❌ Failed to create export session")
            return nil
        }
        
        print("🔊 Export session created successfully")
        print("🔊 Supported file types: \(AVAssetExportSession.exportPresets(compatibleWith: asset))")
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = AVFileType.m4a
        exportSession.audioMix = nil
        
        print("🔊 Starting audio export...")
        await exportSession.export()
        
        print("🔊 Export completed with status: \(exportSession.status.rawValue)")
        if let error = exportSession.error {
            print("❌ Export error details:")
            print("❌ - Description: \(error.localizedDescription)")
            if let nsError = error as? NSError {
                print("❌ - Domain: \(nsError.domain)")
                print("❌ - Code: \(nsError.code)")
                print("❌ - User Info: \(nsError.userInfo)")
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("❌ - Underlying Error Domain: \(underlying.domain)")
                    print("❌ - Underlying Error Code: \(underlying.code)")
                }
            }
        }
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            print("❌ Export failed with status: \(exportSession.status.rawValue)")
            return nil
        }
        
        print("🔊 ==================== AUDIO EXTRACTION COMPLETE ====================\n")
        return audioURL
    }
    
    private func verifyVideoAudio(at url: URL) async {
        Self.logger.notice("🔍 Verifying video at URL: \(url.absoluteString)")
        
        do {
            let asset = AVAsset(url: url)
            let isPlayable = try await asset.load(.isPlayable)
            Self.logger.notice("🔍 Asset is playable: \(isPlayable)")
            
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            Self.logger.notice("🔍 Number of audio tracks: \(tracks.count)")
            
            if let audioTrack = tracks.first {
                let enabled = audioTrack.isEnabled
                Self.logger.notice("🔍 Audio track enabled: \(enabled)")
                
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                Self.logger.notice("🔍 Format descriptions: \(formatDescriptions)")
            } else {
                Self.logger.error("❌ No audio tracks found in the video")
            }
        } catch {
            Self.logger.error("❌ Error verifying video: \(error.localizedDescription)")
        }
    }
}

#Preview {
    do {
        // Create an in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Dream.self, configurations: config)
        let context = container.mainContext
        
        // Create a sample dream
        let sampleDream = Dream(
            id: UUID(uuidString: "3828AE43-6A2E-455D-8426-6831A93DEB15")!, // Match the test ID
            userId: "preview_user",
            title: "Test Dream",
            description: "A test dream for video processing",
            date: Date(),
            videoURL: URL(string: "https://example.com/test.mp4")!,
            dreamDate: Date(),
            videoStyle: .realistic
        )
        
        // Insert the dream into the context
        context.insert(sampleDream)
        
        return VideoProcessingTestView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 
