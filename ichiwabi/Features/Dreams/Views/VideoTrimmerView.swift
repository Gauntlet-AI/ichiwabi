import SwiftUI
import AVKit

class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer
    
    init(url: URL) {
        self.player = AVPlayer(url: url)
    }
}

struct VideoTrimmerView: View {
    let videoURL: URL
    let userId: String
    @StateObject private var processingService = VideoProcessingService()
    @StateObject private var playerViewModel: PlayerViewModel
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var showingError = false
    @State private var showingDreamDetails = false
    @State private var processedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    // Maximum duration in seconds
    private let maxDuration: Double = 180 // 3 minutes
    private let thumbnailHeight: CGFloat = 50
    private let handleWidth: CGFloat = 12
    
    init(videoURL: URL, userId: String) {
        self.videoURL = videoURL
        self.userId = userId
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(url: videoURL))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VideoPreviewView(player: playerViewModel.player)
                    .onAppear {
                        // Reset player when view appears
                        playerViewModel.player.seek(to: CMTime.zero)
                        playerViewModel.player.play()
                        playerViewModel.player.pause()
                    }
                TimelineView(
                    duration: duration,
                    startTime: $startTime,
                    endTime: $endTime,
                    isDraggingStart: $isDraggingStart,
                    isDraggingEnd: $isDraggingEnd,
                    thumbnailHeight: thumbnailHeight,
                    handleWidth: handleWidth,
                    updatePlayerTime: updatePlayerTime
                )
                PlaybackControlsView(
                    isPlaying: $isPlaying,
                    startTime: startTime,
                    endTime: endTime,
                    togglePlayback: togglePlayback,
                    updatePlayerTime: updatePlayerTime
                )
                TimeIndicatorsView(
                    startTime: startTime,
                    endTime: endTime
                )
            }
            .padding()
            .navigationTitle("Trim Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(processingService.isProcessing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        Task {
                            await trimVideo()
                        }
                    }
                    .disabled(processingService.isProcessing)
                }
            }
            .navigationDestination(isPresented: $showingDreamDetails) {
                if let url = processedVideoURL {
                    DreamDetailsView(videoURL: url, userId: userId)
                }
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
            .overlay {
                if processingService.isProcessing {
                    ProgressView("Processing video...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissVideoTrimmer"))) { _ in
                dismiss()
            }
        }
    }
    
    private func loadVideoDuration() async {
        let asset = AVAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration).seconds
            self.duration = duration
            self.endTime = min(duration, maxDuration)
        } catch {
            print("Error loading video duration: \(error)")
        }
    }
    
    private func trimHandle(at time: Double, isDragging: Binding<Bool>) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: handleWidth, height: thumbnailHeight + 20)
            .shadow(radius: isDragging.wrappedValue ? 4 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlayback() {
        if isPlaying {
            playerViewModel.player.pause()
        } else {
            if currentTime >= endTime {
                updatePlayerTime(to: startTime)
            }
            playerViewModel.player.play()
        }
        isPlaying.toggle()
    }
    
    private func updatePlayerTime(to time: Double) {
        playerViewModel.player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }
    
    private func trimVideo() async {
        do {
            let trimmedURL = try await processingService.trimVideo(
                at: videoURL,
                from: startTime,
                to: endTime
            )
            // Navigate to dream details view with trimmed video
            showingDreamDetails = true
            processedVideoURL = trimmedURL
        } catch {
            processingService.error = error
            showingError = true
        }
    }
}

// MARK: - Subviews

private struct VideoPreviewView: View {
    let player: AVPlayer
    
    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(9/16, contentMode: .fit)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

private struct TimelineView: View {
    let duration: Double
    @Binding var startTime: Double
    @Binding var endTime: Double
    @Binding var isDraggingStart: Bool
    @Binding var isDraggingEnd: Bool
    let thumbnailHeight: CGFloat
    let handleWidth: CGFloat
    let updatePlayerTime: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: thumbnailHeight)
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(
                        width: max(0, CGFloat((endTime - startTime) / max(duration, 1)) * geometry.size.width),
                        height: thumbnailHeight
                    )
                    .offset(x: max(0, CGFloat(startTime / max(duration, 1)) * geometry.size.width))
                
                TrimHandleView(
                    time: startTime,
                    isDragging: $isDraggingStart,
                    position: max(0, CGFloat(startTime / max(duration, 1)) * geometry.size.width),
                    thumbnailHeight: thumbnailHeight,
                    handleWidth: handleWidth
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newStart = (Double(value.location.x) / geometry.size.width) * duration
                            startTime = max(0, min(newStart, endTime - 1))
                            updatePlayerTime(startTime)
                        }
                )
                
                TrimHandleView(
                    time: endTime,
                    isDragging: $isDraggingEnd,
                    position: max(0, min(CGFloat(endTime / max(duration, 1)) * geometry.size.width, geometry.size.width)),
                    thumbnailHeight: thumbnailHeight,
                    handleWidth: handleWidth
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newEnd = (Double(value.location.x) / geometry.size.width) * duration
                            endTime = min(duration, max(newEnd, startTime + 1))
                            updatePlayerTime(endTime)
                        }
                )
            }
        }
        .frame(height: thumbnailHeight)
        .padding(.vertical)
    }
}

private struct TrimHandleView: View {
    let time: Double
    @Binding var isDragging: Bool
    let position: CGFloat
    let thumbnailHeight: CGFloat
    let handleWidth: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: handleWidth, height: thumbnailHeight + 20)
            .shadow(radius: isDragging ? 4 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .position(x: position, y: thumbnailHeight / 2)
    }
}

private struct PlaybackControlsView: View {
    @Binding var isPlaying: Bool
    let startTime: Double
    let endTime: Double
    let togglePlayback: () -> Void
    let updatePlayerTime: (Double) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button {
                updatePlayerTime(startTime)
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            
            Button {
                updatePlayerTime(endTime)
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
        }
        .padding()
    }
}

private struct TimeIndicatorsView: View {
    let startTime: Double
    let endTime: Double
    
    var body: some View {
        HStack {
            Text(timeString(from: startTime))
            Spacer()
            Text(timeString(from: endTime - startTime))
            Spacer()
            Text(timeString(from: endTime))
        }
        .monospacedDigit()
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 