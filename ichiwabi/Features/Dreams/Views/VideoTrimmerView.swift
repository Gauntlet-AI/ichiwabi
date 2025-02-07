import SwiftUI
import AVKit

class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer
    @Published var duration: Double = 0
    private var timeObserver: Any?
    
    init() {
        self.player = AVPlayer()
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
    
    func setVideo(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        self.player.replaceCurrentItem(with: playerItem)
        
        // Get video duration
        let duration = playerItem.asset.duration
        if duration != .invalid {
            self.duration = duration.seconds
        }
    }
    
    func updateTrimPoints(startTime: Double, endTime: Double) {
        // Seek to start time
        player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        
        // Remove existing observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        
        // Add new time observer for looping
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak player] time in
            guard let player = player else { return }
            let currentTime = time.seconds
            
            if currentTime >= endTime {
                player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
                player.play()
            }
        }
        
        player.play()
    }
}

struct VideoTrimmerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    @StateObject private var processingService = VideoProcessingService()
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var showingError = false
    @State private var dreamDate = Date()
    @State private var dreamTitle = ""
    @State private var showingDreamDetails = false
    @State private var processedVideoURL: URL?
    
    let videoURL: URL
    let userId: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Video player
                VideoPlayerView(viewModel: playerViewModel)
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(12)
                
                // Date picker
                DatePicker(
                    "Dream Date",
                    selection: $dreamDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)
                
                // Title field
                TextField("Dream Title (Optional)", text: $dreamTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                // Trim controls
                TrimSliderView(
                    duration: playerViewModel.duration,
                    startTime: $startTime,
                    endTime: $endTime
                )
                .padding(.horizontal)
                .onChange(of: startTime) { _ in updateVideoPreview() }
                .onChange(of: endTime) { _ in updateVideoPreview() }
                
                // Duration indicator
                Text(String(format: "Duration: %.1f seconds", endTime - startTime))
                    .foregroundColor(.secondary)
                
                // Action buttons
                HStack {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        Task {
                            do {
                                let processedURL = try await processingService.trimVideo(
                                    at: videoURL,
                                    from: startTime,
                                    to: endTime,
                                    date: dreamDate,
                                    title: dreamTitle.isEmpty ? nil : dreamTitle
                                )
                                
                                // Navigate to dream details view with the processed video
                                let dreamService = DreamService(modelContext: modelContext, userId: userId)
                                // Present dream details view
                                showingDreamDetails = true
                                processedVideoURL = processedURL
                            } catch {
                                processingService.error = error
                                showingError = true
                            }
                        }
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Edit Dream Video")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                playerViewModel.setVideo(url: videoURL)
                playerViewModel.player.play()
            }
            .onDisappear {
                playerViewModel.player.pause()
                playerViewModel.player.replaceCurrentItem(with: nil)
            }
            .task {
                await loadVideoDuration()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = processingService.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $showingDreamDetails) {
                if let processedURL = processedVideoURL {
                    NavigationStack {
                        DreamDetailsView(
                            videoURL: processedURL,
                            userId: userId,
                            initialTitle: dreamTitle.isEmpty ? nil : dreamTitle,
                            trimStartTime: startTime,
                            trimEndTime: endTime
                        )
                    }
                }
            }
            .overlay {
                if processingService.isProcessing {
                    ProgressView("Processing video...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func loadVideoDuration() async {
        let asset = AVAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration).seconds
            self.endTime = min(duration, 180) // 3 minutes
            self.startTime = 0
        } catch {
            print("Error loading video duration: \(error)")
        }
    }
    
    private func updateVideoPreview() {
        playerViewModel.updateTrimPoints(startTime: startTime, endTime: endTime)
    }
}

// MARK: - Subviews

private struct VideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    init(viewModel: VideoPlayerViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .aspectRatio(9/16, contentMode: .fit)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

private struct TrimSliderView: View {
    let duration: Double
    @Binding var startTime: Double
    @Binding var endTime: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(
                        width: max(0, CGFloat((endTime - startTime) / max(duration, 1)) * geometry.size.width),
                        height: 20
                    )
                    .offset(x: max(0, CGFloat(startTime / max(duration, 1)) * geometry.size.width))
                
                TrimHandleView(
                    time: startTime,
                    position: max(0, CGFloat(startTime / max(duration, 1)) * geometry.size.width),
                    thumbnailHeight: 20
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newStart = (Double(value.location.x) / geometry.size.width) * duration
                            startTime = max(0, min(newStart, endTime - 1))
                        }
                )
                
                TrimHandleView(
                    time: endTime,
                    position: max(0, min(CGFloat(endTime / max(duration, 1)) * geometry.size.width, geometry.size.width)),
                    thumbnailHeight: 20
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newEnd = (Double(value.location.x) / geometry.size.width) * duration
                            endTime = min(duration, max(newEnd, startTime + 1))
                        }
                )
            }
        }
        .frame(height: 20)
        .padding(.vertical)
    }
}

private struct TrimHandleView: View {
    let time: Double
    let position: CGFloat
    let thumbnailHeight: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: 12, height: thumbnailHeight + 20)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .position(x: position, y: thumbnailHeight / 2)
    }
} 