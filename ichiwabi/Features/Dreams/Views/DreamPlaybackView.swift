import SwiftUI
import AVKit
import UIKit
import UniformTypeIdentifiers
import SwiftData
import FirebaseFirestore
import FirebaseStorage

struct DreamPlaybackView: View {
    let dream: Dream
    @State private var player: AVPlayer?
    @State private var isSharePresented = false
    @State private var temporaryShareURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let videoUploadService = VideoUploadService()
    private let dreamSyncService: DreamSyncService
    @StateObject private var videoGenerationService = VideoGenerationService()
    
    init(dream: Dream, modelContext: ModelContext) {
        self.dream = dream
        self.dreamSyncService = DreamSyncService(modelContext: modelContext)
    }
    
    private var shareText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return "Dream \(dateFormatter.string(from: dream.dreamDate)):\n\(dream.title)"
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(Theme.darkNavy)
                .navigationTitle("Dream Playback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(Theme.darkNavy, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationBarItems(trailing: navigationButtons)
                .alert("Error", isPresented: .init(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                    }
                }
                .onAppear {
                    Task {
                        await setupPlayer()
                    }
                }
                .onDisappear {
                    player?.pause()
                    player = nil
                    if let tempURL = temporaryShareURL {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
                .sheet(isPresented: $isSharePresented) {
                    if let shareURL = temporaryShareURL {
                        ShareSheet(activityItems: [shareText, shareURL])
                    }
                }
        }
    }
    
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                videoPlayerSection
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) {
                        if !dream.isAIGenerated && !videoGenerationService.isGenerating {
                            DreamGenerationButton {
                                Task {
                                    await generateAIDream()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                            .padding(.top, 49)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 24) {
                    Text(dream.title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(dream.dreamDate.formatted(date: .long, time: .omitted))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    
                    if !dream.dreamDescription.isEmpty {
                        Text(dream.dreamDescription)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var videoPlayerSection: some View {
        Group {
            if dream.processingStatus == .pending {
                pendingVideoOverlay
            } else if let player = player {
                GeometryReader { geometry in
                    let videoHeight = min(geometry.size.width * (16/9), 600)
                    
                    ZStack {
                        VideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .frame(width: geometry.size.width)
                            .frame(maxWidth: .infinity)
                            .frame(height: videoHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                        if videoGenerationService.isGenerating {
                            generationLoadingOverlay
                        }
                    }
                }
                .frame(height: min(UIScreen.main.bounds.width * (16/9), 600))
            } else if isLoading {
                loadingView
            } else {
                loadingView
            }
        }
    }
    
    private var pendingVideoOverlay: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black.opacity(0.7),
                    Color(red: 0.2, green: 0.0, blue: 0.4).opacity(0.8),
                    Color.black.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: min(UIScreen.main.bounds.width * (16/9), 600))
            
            VStack(spacing: 24) {
                // Progress indicator
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                // Status text with pulsing animation
                Text("Generating your dream video...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(0.9)
                    .modifier(PulsingTextModifier())
                
                Text("This may take a few minutes.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Button {
                    Task {
                        await generatePendingVideo()
                    }
                } label: {
                    Text("Generate Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 16)
            }
            .padding()
        }
    }
    
    private var generationLoadingOverlay: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.black.opacity(0.7),
                    Color(red: 0.2, green: 0.0, blue: 0.4).opacity(0.8),
                    Color.black.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 24) {
                // Progress indicator
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                // Status text with pulsing animation
                Text(videoGenerationService.currentStage.description)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(0.9)
                    .modifier(PulsingTextModifier())
                
                if videoGenerationService.currentStage != .notStarted {
                    Text("Please wait while we make your dream real...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        
                    Button {
                        dismiss()
                    } label: {
                        Text("Go to My Dreams")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.top, 16)
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        ProgressView(isLoading ? "Loading video..." : "")
            .frame(maxWidth: .infinity)
            .frame(height: 600)
            .foregroundColor(Theme.textPrimary)
    }
    
    private var navigationButtons: some View {
        HStack {
            Button {
                Task {
                    await prepareAndShare()
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Theme.textPrimary)
            }
            .disabled(isLoading)
            
            Button("Done") {
                Task {
                    do {
                        // Create DreamService for syncing
                        let dreamService = DreamService(modelContext: modelContext, userId: dream.userId)
                        
                        // Update the dream's sync status and save
                        dream.isSynced = false
                        dream.updatedAt = Date()
                        try await dreamService.saveDream(dream)
                        
                        // Clean up resources
                        player?.pause()
                        player = nil
                        if let tempURL = temporaryShareURL {
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                        
                        // Dismiss the view
                        dismiss()
                    } catch {
                        errorMessage = "Failed to sync dream: \(error.localizedDescription)"
                    }
                }
            }
            .foregroundColor(Theme.textPrimary)
        }
    }
    
    private func setupPlayer() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("\n📼 ==================== DREAM PLAYBACK ====================")
            print("📼 Setting up video player for dream: \(dream.dreamId)")
            print("📼 Dream details:")
            print("📼 - Title: \(dream.title)")
            print("📼 - User ID: \(dream.userId)")
            print("📼 - Local path: \(dream.localVideoPath ?? "none")")
            print("📼 - Video URL: \(dream.videoURL)")
            
            // First try to load from local storage
            if let localPath = dream.localVideoPath,
               let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                // Construct full path including dreams/userId subdirectories
                let fullPath = "dreams/\(dream.userId)/\(localPath)"
                let localURL = documentsPath.appendingPathComponent(fullPath)
                print("📼 Checking for cached video at: \(localURL.path)")
                
                if FileManager.default.fileExists(atPath: localURL.path) {
                    print("📼 Found cached video, setting up player")
                    await setupPlayerWithURL(localURL)
                    return
                } else {
                    print("⚠️ Local path exists but file not found: \(localURL.path)")
                    // Clear the local path since the file is missing
                    dream.localVideoPath = nil
                    try modelContext.save()
                }
            }
            
            // If no local video or file was missing, download it
            print("📼 Attempting to download video from cloud")
            try await dreamSyncService.loadVideoForDream(dream)
            
            // After download, verify we have a valid local path and file
            if let localPath = dream.localVideoPath,
               let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fullPath = "dreams/\(dream.userId)/\(localPath)"
                let localURL = documentsPath.appendingPathComponent(fullPath)
                print("📼 Full path after download: \(fullPath)")
                
                // Download audio file from Firebase Storage if needed
                if let audioPath = dream.localAudioPath {
                    print("📼 Attempting to download audio file")
                    let storage = Storage.storage()
                    let audioRef = storage.reference().child("users/\(dream.userId)/audio/\(dream.dreamId).m4a")
                    
                    let audioLocalPath = documentsPath.appendingPathComponent("dreams/\(dream.userId)/\(audioPath)")
                    if !FileManager.default.fileExists(atPath: audioLocalPath.path) {
                        print("📼 Downloading audio file from Firebase Storage")
                        _ = try await audioRef.write(toFile: audioLocalPath)
                        print("📼 Audio file downloaded successfully")
                    } else {
                        print("📼 Using cached audio file")
                    }
                }
                
                if FileManager.default.fileExists(atPath: localURL.path) {
                    print("📼 Setting up player with downloaded video")
                    await setupPlayerWithURL(localURL)
                } else {
                    throw NSError(domain: "DreamPlayback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded video file not found"])
                }
            } else {
                throw NSError(domain: "DreamPlayback", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video download succeeded but local path is missing"])
            }
        } catch {
            print("\n❌ ==================== ERROR ====================")
            print("❌ Failed to load video: \(error)")
            let nsError = error as NSError
            print("❌ Error details:")
            print("❌ - Domain: \(nsError.domain)")
            print("❌ - Code: \(nsError.code)")
            print("❌ - Description: \(nsError.localizedDescription)")
            print("❌ - User Info: \(nsError.userInfo)")
            print("❌ ==================== END ====================\n")
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
    }
    
    private func setupPlayerWithURL(_ url: URL) async {
        // Create asset and get duration
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration).seconds
            print("📼 Video duration: \(duration) seconds")
            
            // Create player item with the asset
            let playerItem = AVPlayerItem(asset: asset)
            
            await MainActor.run {
                player = AVPlayer(playerItem: playerItem)
                
                // Set up periodic playback observation for looping
                player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak player] time in
                    let currentTime = time.seconds
                    
                    // Loop at video end
                    if currentTime >= duration {
                        player?.seek(to: .zero)
                        player?.play()
                    }
                }
                
                player?.play()
            }
            print("📼 Player setup complete")
            print("📼 ==================== END ====================\n")
        } catch {
            print("❌ Error setting up player: \(error)")
            errorMessage = "Failed to setup video player: \(error.localizedDescription)"
        }
    }
    
    private func prepareAndShare() async {
        guard let localPath = dream.localVideoPath,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Video file not found"
            return
        }
        
        let fullPath = "dreams/\(dream.userId)/\(localPath)"
        let localURL = documentsPath.appendingPathComponent(fullPath)
        
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            errorMessage = "Video file not found at expected location"
            return
        }
        
        do {
            // Create a temporary copy for sharing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: localURL, to: tempURL)
            
            // Clean up any previous temporary URL
            if let oldURL = temporaryShareURL {
                try? FileManager.default.removeItem(at: oldURL)
            }
            
            temporaryShareURL = tempURL
            isSharePresented = true
        } catch {
            errorMessage = "Failed to prepare video for sharing: \(error.localizedDescription)"
        }
    }
    
    private func generateAIDream() async {
        do {
            // Store the original video URL
            dream.originalVideoURL = dream.videoURL
            
            // Update processing status
            dream.isProcessing = true
            dream.processingStatus = .aiGenerating
            try modelContext.save()
            
            // Start the generation process in a background task
            Task.detached {
                do {
                    // Generate the video
                    let newVideoURL = try await videoGenerationService.generateVideo(for: dream)
                    
                    // Update the dream with the new video on the main thread
                    await MainActor.run {
                        if let url = URL(string: newVideoURL) {
                            dream.videoURL = url
                            dream.isAIGenerated = true
                            dream.aiGenerationDate = Date()
                            dream.isSynced = false
                            dream.isProcessing = false
                            dream.processingStatus = .aiCompleted
                            
                            // Clear the local path so setupPlayer will download the new video
                            dream.localVideoPath = nil
                            
                            // Save changes
                            try? modelContext.save()
                        } else {
                            dream.isProcessing = false
                            dream.processingStatus = .failed
                            dream.processingError = "Invalid video URL returned"
                            try? modelContext.save()
                        }
                    }
                } catch {
                    await MainActor.run {
                        dream.isProcessing = false
                        dream.processingStatus = .failed
                        dream.processingError = error.localizedDescription
                        try? modelContext.save()
                    }
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func generatePendingVideo() async {
        do {
            // Update processing status
            dream.isProcessing = true
            dream.processingStatus = .processing
            try modelContext.save()
            
            // Start the generation process in a background task
            Task.detached {
                do {
                    // Generate the video
                    let newVideoURL = try await videoGenerationService.generateVideo(for: dream)
                    
                    // Update the dream with the new video on the main thread
                    await MainActor.run {
                        if let url = URL(string: newVideoURL) {
                            dream.videoURL = url
                            dream.isProcessing = false
                            dream.processingStatus = .completed
                            dream.isSynced = false
                            
                            // Clear the local path so setupPlayer will download the new video
                            dream.localVideoPath = nil
                            
                            // Save changes
                            try? modelContext.save()
                            
                            // Refresh the player
                            Task {
                                await setupPlayer()
                            }
                        } else {
                            dream.isProcessing = false
                            dream.processingStatus = .failed
                            dream.processingError = "Invalid video URL returned"
                            try? modelContext.save()
                            
                            errorMessage = "Failed to generate video: Invalid URL returned"
                        }
                    }
                } catch {
                    await MainActor.run {
                        dream.isProcessing = false
                        dream.processingStatus = .failed
                        dream.processingError = error.localizedDescription
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude certain activity types that might not handle video well
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .markupAsPDF
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Using shared PulsingTextModifier from Core/Views/Modifiers

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Dream.self, configurations: config)
        
        return DreamPlaybackView(
            dream: Dream(
                userId: "preview-user",
                title: "Flying Dream",
                description: "I was flying over mountains...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video.mp4")!,
                dreamDate: Date()
            ),
            modelContext: container.mainContext
        )
        .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 
