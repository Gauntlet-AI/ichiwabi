import SwiftUI
import AVKit

struct VideoTrimmerView: View {
    let videoURL: URL
    @StateObject private var processingService = VideoProcessingService()
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    // Maximum duration in seconds
    private let maxDuration: Double = 180 // 3 minutes
    private let thumbnailHeight: CGFloat = 50
    private let handleWidth: CGFloat = 12
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        let player = AVPlayer(url: videoURL)
        _player = State(initialValue: player)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Video preview
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Timeline and trim handles
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Video thumbnails background
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: thumbnailHeight)
                        
                        // Selected range
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(
                                width: CGFloat((endTime - startTime) / duration) * geometry.size.width,
                                height: thumbnailHeight
                            )
                            .offset(x: CGFloat(startTime / duration) * geometry.size.width)
                        
                        // Start handle
                        trimHandle(at: startTime, isDragging: $isDraggingStart)
                            .position(
                                x: CGFloat(startTime / duration) * geometry.size.width,
                                y: thumbnailHeight / 2
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newStart = (Double(value.location.x) / geometry.size.width) * duration
                                        startTime = max(0, min(newStart, endTime - 1))
                                        updatePlayerTime(to: startTime)
                                    }
                            )
                        
                        // End handle
                        trimHandle(at: endTime, isDragging: $isDraggingEnd)
                            .position(
                                x: CGFloat(endTime / duration) * geometry.size.width,
                                y: thumbnailHeight / 2
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newEnd = (Double(value.location.x) / geometry.size.width) * duration
                                        endTime = min(duration, max(newEnd, startTime + 1))
                                        updatePlayerTime(to: endTime)
                                    }
                            )
                    }
                }
                .frame(height: thumbnailHeight)
                .padding(.vertical)
                
                // Playback controls
                HStack(spacing: 20) {
                    Button {
                        updatePlayerTime(to: startTime)
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
                        updatePlayerTime(to: endTime)
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                }
                .padding()
                
                // Time indicators
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
            .onDisappear {
                player?.pause()
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
            player?.pause()
        } else {
            if currentTime >= endTime {
                updatePlayerTime(to: startTime)
            }
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func updatePlayerTime(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }
    
    private func trimVideo() async {
        do {
            _ = try await processingService.trimVideo(
                at: videoURL,
                from: startTime,
                to: endTime
            )
            // TODO: Navigate to dream details view with trimmed video
            dismiss()
        } catch {
            processingService.error = error
            showingError = true
        }
    }
} 