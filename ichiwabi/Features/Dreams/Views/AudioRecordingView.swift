import SwiftUI
import AVFoundation

struct AudioRecordingView: View {
    @StateObject private var audioService = AudioRecordingService()
    @State private var recordedAudioURL: URL?
    @State private var selectedStyle: DreamVideoStyle?
    @State private var isGenerating = false
    @State private var showError = false
    
    let onComplete: (URL, DreamVideoStyle) -> Void
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Timer and waveform
                VStack(spacing: 16) {
                    // Timer
                    Text(timeString(from: recordedAudioURL != nil ? audioService.currentTime : audioService.recordingDuration))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .onChange(of: audioService.recordingDuration) { _, newValue in
                            print("🎤 Duration: \(newValue)")
                        }
                        .onChange(of: audioService.currentTime) { _, newValue in
                            print("🎤 Playback time: \(newValue)")
                        }
                    
                    // Waveform
                    WaveformView(levels: audioService.audioLevels)
                        .frame(height: 100)
                        .animation(.easeInOut(duration: 0.1), value: audioService.audioLevels)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Style selection buttons (only show after recording)
                if recordedAudioURL != nil {
                    VStack(spacing: 16) {
                        Text("Select Video Style")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            StyleButton(
                                title: "Realistic",
                                isSelected: selectedStyle == .realistic,
                                action: { selectedStyle = .realistic }
                            )
                            
                            StyleButton(
                                title: "Animated",
                                isSelected: selectedStyle == .animated,
                                action: { selectedStyle = .animated }
                            )
                            
                            StyleButton(
                                title: "Cursed",
                                isSelected: selectedStyle == .cursed,
                                action: { selectedStyle = .cursed }
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Control buttons
                VStack(spacing: 24) {
                    if let url = recordedAudioURL {
                        // Playback controls
                        HStack(spacing: 40) {
                            Button {
                                audioService.togglePlayback(url: url)
                            } label: {
                                Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                // Reset recording
                                audioService.cleanup()
                                recordedAudioURL = nil
                                selectedStyle = nil
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Generate button
                        if let style = selectedStyle {
                            Button {
                                generateDream(url: url, style: style)
                            } label: {
                                Text("Generate Dream")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1, green: 0.8, blue: 0.9), // Pastel Pink
                                                Color(red: 0.6, green: 0.7, blue: 1)  // Pastel Blue
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                            .disabled(isGenerating)
                        }
                    } else {
                        // Record button
                        HStack(spacing: 40) {
                            Button {
                                handleRecordButton()
                            } label: {
                                Image(systemName: audioService.isRecording ? "stop.circle.fill" : "record.circle.fill")
                                    .font(.system(size: 84))
                                    .foregroundColor(audioService.isRecording ? .red : .white)
                            }
                            
                            if audioService.isRecording {
                                Button {
                                    print("🎤 Toggle pause tapped, current state - isRecording: \(audioService.isRecording), isPaused: \(audioService.isPaused)")
                                    audioService.togglePause()
                                } label: {
                                    Image(systemName: audioService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 84))
                                        .foregroundColor(audioService.isPaused ? .white : .yellow)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3), value: audioService.isRecording)
                        .animation(.spring(response: 0.3), value: audioService.isPaused)
                        .onChange(of: audioService.isRecording) { _, newValue in
                            print("🎤 isRecording changed to: \(newValue)")
                        }
                        .onChange(of: audioService.isPaused) { _, newValue in
                            print("🎤 isPaused changed to: \(newValue)")
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            
            if isGenerating {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(audioService.errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func handleRecordButton() {
        if audioService.isRecording {
            print("🎤 Stopping recording...")
            Task {
                if let url = try? await audioService.stopRecording() {
                    recordedAudioURL = url
                    print("🎤 Recording stopped, URL: \(url)")
                }
            }
        } else {
            print("🎤 Starting recording...")
            Task {
                do {
                    // Don't set recordedAudioURL when starting recording
                    _ = try await audioService.startRecording()
                    print("🎤 Recording started")
                } catch {
                    print("🎤 Recording failed: \(error)")
                    showError = true
                }
            }
        }
    }
    
    private func generateDream(url: URL, style: DreamVideoStyle) {
        isGenerating = true
        audioService.stopPlayback()
        onComplete(url, style)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Style Button
struct StyleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.8, blue: 0.9), // Pastel Pink
                                Color(red: 0.6, green: 0.7, blue: 1)  // Pastel Blue
                            ],
                            startPoint: UnitPoint(
                                x: cos(2 * .pi * animationPhase) * 0.5 + 0.5,
                                y: sin(2 * .pi * animationPhase) * 0.5
                            ),
                            endPoint: UnitPoint(
                                x: cos(2 * .pi * (animationPhase + 0.5)) * 0.5 + 0.5,
                                y: sin(2 * .pi * (animationPhase + 0.5)) * 0.5 + 1
                            )
                        )
                        .opacity(0.8)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 3)
                                .repeatForever(autoreverses: false)
                            ) {
                                animationPhase = 1
                            }
                        }
                    } else {
                        Color.black.opacity(0.3)
                    }
                }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(), value: isSelected)
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let levels: [CGFloat]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 4)
                        .frame(height: getHeight(at: index, size: geometry.size))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func getHeight(at index: Int, size: CGSize) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight = size.height
        
        guard index < levels.count else {
            return minHeight
        }
        
        return minHeight + (maxHeight - minHeight) * levels[index]
    }
}

#Preview {
    AudioRecordingView { url, style in
        print("Recording completed: \(url)")
        print("Selected style: \(style)")
    }
} 