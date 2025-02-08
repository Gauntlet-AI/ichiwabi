import SwiftUI
import AVKit
import UIKit
import UniformTypeIdentifiers
import SwiftData

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
                    setupPlayer()
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
            if let player = player {
                GeometryReader { geometry in
                    let videoHeight = min(geometry.size.width * (16/9), 600)
                    
                    ZStack {
                        VideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .frame(width: geometry.size.width)
                            .frame(maxWidth: .infinity)
                            .frame(height: videoHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                dismiss()
            }
            .foregroundColor(Theme.textPrimary)
        }
    }
    
    private func setupPlayer() {
        Task {
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
                    print("📼 Full path structure:")
                    print("📼 - Documents path: \(documentsPath.path)")
                    print("📼 - Relative path: \(fullPath)")
                    print("📼 - Final URL: \(localURL.path)")
                    
                    // Check if parent directory exists
                    let parentDir = localURL.deletingLastPathComponent()
                    let dirExists = FileManager.default.fileExists(atPath: parentDir.path)
                    print("📼 Parent directory exists: \(dirExists)")
                    
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        print("📼 Found cached video, setting up player")
                        
                        // Create asset and get duration
                        let asset = AVAsset(url: localURL)
                        let duration = try await asset.load(.duration).seconds
                        print("📼 Video duration: \(duration) seconds")
                        
                        // Create player item with the asset
                        let playerItem = AVPlayerItem(asset: asset)
                        
                        await MainActor.run {
                            player = AVPlayer(playerItem: playerItem)
                            
                            // Set initial position to trim start
                            if dream.trimStartTime > 0 {
                                player?.seek(to: CMTime(seconds: dream.trimStartTime, preferredTimescale: 600))
                            }
                            
                            // Set up playback observation for trim points
                            player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak player] time in
                                let currentTime = time.seconds
                                
                                // If we've reached the trim end point or the video end
                                if dream.trimEndTime > 0 && currentTime >= dream.trimEndTime {
                                    // Loop back to trim start
                                    player?.seek(to: CMTime(seconds: dream.trimStartTime, preferredTimescale: 600))
                                    player?.play()
                                } else if dream.trimEndTime == 0 && currentTime >= duration {
                                    // If no trim end point, loop at video end
                                    player?.seek(to: .zero)
                                    player?.play()
                                }
                            }
                            
                            player?.play()
                        }
                        print("📼 Player setup complete")
                        print("📼 ==================== END ====================\n")
                        return
                    } else {
                        print("⚠️ Local path exists but file not found: \(localURL.path)")
                        // Clear the local path since the file is missing
                        dream.localVideoPath = nil
                        try modelContext.save()
                    }
                } else {
                    print("📼 No local video path available")
                }
                
                // If no local video or file was missing, download it
                print("📼 Attempting to download video from cloud")
                print("📼 Video URL: \(dream.videoURL)")
                
                try await dreamSyncService.loadVideoForDream(dream)
                
                // After download, verify we have a valid local path and file
                if let localPath = dream.localVideoPath,
                   let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    // Construct full path including dreams/userId subdirectories
                    let fullPath = "dreams/\(dream.userId)/\(localPath)"
                    let localURL = documentsPath.appendingPathComponent(fullPath)
                    print("📼 Full path after download: \(fullPath)")
                    print("📼 Checking downloaded file:")
                    print("📼 - Local URL: \(localURL.path)")
                    
                    // Check parent directory
                    let parentDir = localURL.deletingLastPathComponent()
                    let dirExists = FileManager.default.fileExists(atPath: parentDir.path)
                    print("📼 Parent directory exists: \(dirExists)")
                    
                    // Double check the file exists after download
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        print("📼 Setting up player with downloaded video at: \(localURL.path)")
                        
                        // Create asset and get duration
                        let asset = AVAsset(url: localURL)
                        let duration = try await asset.load(.duration).seconds
                        print("📼 Video duration: \(duration) seconds")
                        
                        // Create player item with the asset
                        let playerItem = AVPlayerItem(asset: asset)
                        
                        await MainActor.run {
                            player = AVPlayer(playerItem: playerItem)
                            
                            // Set initial position to trim start
                            if dream.trimStartTime > 0 {
                                player?.seek(to: CMTime(seconds: dream.trimStartTime, preferredTimescale: 600))
                            }
                            
                            // Set up playback observation for trim points
                            player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak player] time in
                                let currentTime = time.seconds
                                
                                // If we've reached the trim end point or the video end
                                if dream.trimEndTime > 0 && currentTime >= dream.trimEndTime {
                                    // Loop back to trim start
                                    player?.seek(to: CMTime(seconds: dream.trimStartTime, preferredTimescale: 600))
                                    player?.play()
                                } else if dream.trimEndTime == 0 && currentTime >= duration {
                                    // If no trim end point, loop at video end
                                    player?.seek(to: .zero)
                                    player?.play()
                                }
                            }
                            
                            player?.play()
                        }
                        print("📼 Player setup complete")
                        print("📼 ==================== END ====================\n")
                    } else {
                        print("⚠️ Downloaded file not found at: \(localURL.path)")
                        throw NSError(domain: "DreamPlayback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded video file not found"])
                    }
                } else {
                    print("⚠️ No local path after download")
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
                await MainActor.run {
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func prepareAndShare() async {
        guard let localPath = dream.localVideoPath,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Cannot share: missing local path or documents directory")
            return
        }
        
        // Construct full path including dreams/userId subdirectories
        let fullPath = "dreams/\(dream.userId)/\(localPath)"
        let sourceURL = documentsPath.appendingPathComponent(fullPath)
        print("📤 Preparing to share video from: \(sourceURL.path)")
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("dream-share-\(UUID().uuidString).mp4")
        
        do {
            // Verify source file exists
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                print("⚠️ Source file not found at: \(sourceURL.path)")
                return
            }
            
            // Copy file to temporary directory for sharing
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            
            // Update state on main thread
            await MainActor.run {
                temporaryShareURL = tempURL
                isSharePresented = true
            }
            print("✅ Video prepared for sharing")
        } catch {
            print("❌ Failed to prepare video for sharing: \(error)")
            let nsError = error as NSError
            print("❌ Error details:")
            print("❌ - Domain: \(nsError.domain)")
            print("❌ - Code: \(nsError.code)")
            print("❌ - Description: \(nsError.localizedDescription)")
            print("❌ - User Info: \(nsError.userInfo)")
        }
    }
}

// ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create an array of activity items with proper type handling
        let items = activityItems.map { item -> Any in
            if let url = item as? URL {
                // Create an item provider that supports multiple video formats
                let provider = NSItemProvider()
                
                // Register common video types
                let videoTypes = [
                    UTType.mpeg4Movie.identifier,
                    UTType.movie.identifier,
                    "public.movie",
                    "public.video",
                    "public.audiovisual-content"
                ]
                
                for type in videoTypes {
                    provider.registerDataRepresentation(
                        forTypeIdentifier: type,
                        visibility: .all
                    ) { completion in
                        do {
                            let data = try Data(contentsOf: url)
                            completion(data, nil)
                        } catch {
                            completion(nil, error)
                        }
                        return nil
                    }
                }
                
                // Also register as a file URL for apps that prefer that
                provider.registerFileRepresentation(
                    forTypeIdentifier: UTType.mpeg4Movie.identifier,
                    fileOptions: [.openInPlace],
                    visibility: .all
                ) { completion in
                    completion(url, true, nil)
                    return nil
                }
                
                return provider
            }
            return item
        }
        
        let controller = UIActivityViewController(
            activityItems: items,
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