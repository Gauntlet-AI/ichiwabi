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
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Video player
                    if let player = player {
                        ZStack(alignment: .bottomLeading) {
                            VideoPlayer(player: player)
                                .aspectRatio(9/16, contentMode: .fit)
                                .frame(maxHeight: 400)
                                .cornerRadius(12)
                            
                            WatermarkView(
                                date: dream.dreamDate,
                                title: dream.title
                            )
                        }
                    } else if isLoading {
                        ProgressView("Loading video...")
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                    }
                    
                    // Dream details
                    VStack(alignment: .leading, spacing: 16) {
                        Text(dream.title)
                            .font(.title2)
                            .bold()
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(dream.dreamDate.formatted(date: .long, time: .omitted))
                        }
                        .foregroundStyle(.secondary)
                        
                        if let transcript = dream.transcript {
                            Text("Transcript")
                                .font(.headline)
                                .padding(.top)
                            
                            Text(transcript)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Dream Playback")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                HStack {
                    Button {
                        Task {
                            await prepareAndShare()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isLoading)
                    
                    Button("Done") {
                        dismiss()
                    }
                }
            )
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
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            // Clean up temporary file if it exists
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
    
    private func setupPlayer() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                print("📼 Setting up video player for dream: \(dream.dreamId)")
                
                // First try to load from local storage
                if let localPath = dream.localVideoPath,
                   let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    // Construct full path including dreams/userId subdirectories
                    let fullPath = "dreams/\(dream.userId)/\(localPath)"
                    let localURL = documentsPath.appendingPathComponent(fullPath)
                    print("📼 Checking for cached video at: \(localURL.path)")
                    print("📼 Full path structure: \(fullPath)")
                    
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        print("📼 Found cached video, setting up player")
                        await MainActor.run {
                            player = AVPlayer(url: localURL)
                            player?.play()
                        }
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
                    
                    // Double check the file exists after download
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        print("📼 Setting up player with downloaded video at: \(localURL.path)")
                        await MainActor.run {
                            player = AVPlayer(url: localURL)
                            player?.play()
                        }
                    } else {
                        print("⚠️ Downloaded file not found at: \(localURL.path)")
                        throw NSError(domain: "DreamPlayback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded video file not found"])
                    }
                } else {
                    print("⚠️ No local path after download")
                    throw NSError(domain: "DreamPlayback", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video download succeeded but local path is missing"])
                }
            } catch {
                print("❌ Failed to load video: \(error)")
                print("❌ Error details: \(error)")
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
            
            print("📤 Copying to temporary location: \(tempURL.path)")
            // Copy file to temporary directory
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            
            // Update state on main thread
            await MainActor.run {
                temporaryShareURL = tempURL
                isSharePresented = true
            }
            print("✅ Video prepared for sharing")
        } catch {
            print("❌ Failed to prepare video for sharing: \(error)")
            if let nsError = error as NSError? {
                print("❌ Error details:")
                print("❌ - Domain: \(nsError.domain)")
                print("❌ - Code: \(nsError.code)")
                print("❌ - Description: \(nsError.localizedDescription)")
                print("❌ - User Info: \(nsError.userInfo)")
            }
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