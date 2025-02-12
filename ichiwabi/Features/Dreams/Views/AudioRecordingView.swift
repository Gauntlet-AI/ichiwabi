import SwiftUI
import AVFoundation

struct AudioRecordingView: View {
    @StateObject private var audioService = AudioRecordingService()
    @State private var recordedAudioURL: URL?
    @State private var selectedStyle: DreamVideoStyle?
    @State private var isGenerating = false
    @State private var showError = false
    @State private var isTranscribing = false
    @State private var transcribedText: String?
    @State private var editedTranscription: String = ""
    @State private var isGeneratingTitle = false
    @State private var generatedTitle: String?
    @State private var editedTitle: String = ""
    @State private var generatedDream: Dream?
    @State private var showDreamPlayback = false
    @Environment(\.dismiss) private var dismiss
    
    private let apiService = APIService()
    private let videoProcessingService = VideoProcessingService()
    private let authService = AuthService.shared
    @Environment(\.modelContext) private var modelContext
    let onComplete: (URL, DreamVideoStyle) -> Void
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Navigation bar
                HStack {
                    Button {
                        // Stop recording/playback if active
                        if audioService.isRecording {
                            audioService.cleanup()
                        }
                        if audioService.isPlaying {
                            audioService.stopPlayback()
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.leading)
                    
                    Spacer()
                }
                .padding(.top)
                
                // Timer and waveform
                VStack(spacing: 12) {
                    // Timer
                    Text(timeString(from: recordedAudioURL != nil ? audioService.currentTime : audioService.recordingDuration))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .onChange(of: audioService.recordingDuration) { _, newValue in
                            print("🎤 Duration: \(newValue)")
                        }
                        .onChange(of: audioService.currentTime) { _, newValue in
                            print("🎤 Playback time: \(newValue)")
                        }
                    
                    // Waveform
                    WaveformView(levels: audioService.audioLevels)
                        .frame(height: 80)
                        .animation(.easeInOut(duration: 0.1), value: audioService.audioLevels)
                }
                .padding(.top, 20)
                
                if recordedAudioURL != nil {
                    VStack(spacing: 12) {
                        // Processing Status
                        if isTranscribing || isGeneratingTitle {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text(isTranscribing ? "Transcribing your dream..." : "Generating title...")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Title Section
                        if let title = generatedTitle {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dream Title")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextField("Title", text: .init(
                                    get: { editedTitle.isEmpty ? title : editedTitle },
                                    set: { editedTitle = $0 }
                                ))
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .onAppear {
                                    if editedTitle.isEmpty {
                                        editedTitle = title
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .transition(.opacity)
                        }
                        
                        // Transcription Section
                        if let text = transcribedText {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Dream Description")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextEditor(text: .init(
                                    get: { editedTranscription.isEmpty ? text : editedTranscription },
                                    set: { editedTranscription = $0 }
                                ))
                                .frame(height: 80)
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .onAppear {
                                    if editedTranscription.isEmpty {
                                        editedTranscription = text
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .transition(.opacity)
                        }
                    }
                }
                
                Spacer()
                
                // Style selection buttons (only show after transcription)
                if recordedAudioURL != nil && !isTranscribing && transcribedText != nil {
                    VStack(spacing: 12) {
                        Text("Select Video Style")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
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
                
                // Control buttons
                VStack(spacing: 16) {
                    if let url = recordedAudioURL {
                        // Playback controls
                        HStack(spacing: 32) {
                            Button {
                                audioService.togglePlayback(url: url)
                            } label: {
                                Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                // Reset recording
                                audioService.cleanup()
                                recordedAudioURL = nil
                                selectedStyle = nil
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.system(size: 56))
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
                                    .frame(height: 44)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1, green: 0.8, blue: 0.9),
                                                Color(red: 0.6, green: 0.7, blue: 1)
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
                        HStack(spacing: 32) {
                            Button {
                                handleRecordButton()
                            } label: {
                                Image(systemName: audioService.isRecording ? "stop.circle.fill" : "record.circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundColor(audioService.isRecording ? .red : .white)
                            }
                            
                            if audioService.isRecording {
                                Button {
                                    print("🎤 Toggle pause tapped, current state - isRecording: \(audioService.isRecording), isPaused: \(audioService.isPaused)")
                                    audioService.togglePause()
                                } label: {
                                    Image(systemName: audioService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 72))
                                        .foregroundColor(audioService.isPaused ? .white : .yellow)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3), value: audioService.isRecording)
                        .animation(.spring(response: 0.3), value: audioService.isPaused)
                    }
                }
                .padding(.bottom, 20)
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
        .fullScreenCover(isPresented: $showDreamPlayback, content: {
            if let dream = generatedDream {
                DreamPlaybackView(dream: dream, modelContext: modelContext)
                    .onDisappear {
                        // Dismiss the AudioRecordingView when DreamPlaybackView is dismissed
                        dismiss()
                    }
            }
        })
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Stop recording/playback if active
                    if audioService.isRecording {
                        audioService.cleanup()
                    }
                    if audioService.isPlaying {
                        audioService.stopPlayback()
                    }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func handleRecordButton() {
        if audioService.isRecording {
            print("🎤 Stopping recording...")
            Task {
                if let url = try? await audioService.stopRecording() {
                    recordedAudioURL = url
                    print("🎤 Recording stopped, URL: \(url)")
                    await transcribeAudio(url: url)
                }
            }
        } else {
            print("🎤 Starting recording...")
            resetStates()
            Task {
                do {
                    _ = try await audioService.startRecording()
                    print("🎤 Recording started")
                } catch {
                    print("🎤 Recording failed: \(error)")
                    showError = true
                }
            }
        }
    }
    
    private func resetStates() {
        recordedAudioURL = nil
        selectedStyle = nil
        
        isTranscribing = false
        transcribedText = nil
        editedTranscription = ""
        
        isGeneratingTitle = false
        generatedTitle = nil
        editedTitle = ""
    }
    
    private func transcribeAudio(url: URL) async {
        isTranscribing = true
        do {
            let transcription = try await apiService.transcribeAudio(fileURL: url)
            transcribedText = transcription
            // Generate title after successful transcription
            await generateTitle(from: transcription)
        } catch {
            showError = true
            audioService.errorMessage = "Transcription failed: \(error.localizedDescription)"
        }
        isTranscribing = false
    }
    
    private func generateTitle(from description: String) async {
        isGeneratingTitle = true
        do {
            let title = try await apiService.generateTitle(dream: description)
            generatedTitle = title
        } catch {
            showError = true
            audioService.errorMessage = "Title generation failed: \(error.localizedDescription)"
        }
        isGeneratingTitle = false
    }
    
    private func generateDream(url: URL, style: DreamVideoStyle) {
        isGenerating = true
        audioService.stopPlayback()
        
        Task {
            do {
                // Ensure we have a signed-in user
                if authService.currentUserId == nil {
                    try await authService.signInAnonymously()
                }
                
                guard let userId = authService.currentUserId else {
                    throw NSError(domain: "AudioRecording", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to get user ID"
                    ])
                }
                
                // Get the title to use
                let dreamTitle = editedTitle.isEmpty ? (generatedTitle ?? "Untitled Dream") : editedTitle
                
                // Process and upload the video
                let processedResult = try await videoProcessingService.processAndUploadVideo(
                    audioURL: url,
                    userId: userId,
                    dreamId: UUID().uuidString,
                    style: style,
                    title: dreamTitle
                )
                
                // Create new Dream instance
                let dream = Dream(
                    userId: userId,
                    title: dreamTitle,
                    description: editedTranscription.isEmpty ? (transcribedText ?? "") : editedTranscription,
                    date: Date(),
                    videoURL: processedResult.videoURL,
                    audioURL: processedResult.audioURL,
                    transcript: transcribedText,
                    dreamDate: Date(),
                    localVideoPath: processedResult.localPath,
                    localAudioPath: url.lastPathComponent,
                    videoStyle: style,
                    isProcessing: false,
                    processingProgress: 1.0,
                    processingStatus: .completed
                )
                
                // Save to SwiftData
                modelContext.insert(dream)
                try modelContext.save()
                
                await MainActor.run {
                    self.generatedDream = dream
                    self.isGenerating = false
                    self.showDreamPlayback = true
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.showError = true
                    audioService.errorMessage = "Failed to generate dream: \(error.localizedDescription)"
                }
            }
        }
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