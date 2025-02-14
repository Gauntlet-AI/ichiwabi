//
//  ContentView.swift
//  WatchExtension Watch App
//
//  Created by Gauntlet on 2/13/R7.
//

import SwiftUI
import AVFoundation
import SwiftData
import WatchKit
@preconcurrency import WatchConnectivity

// Import WatchDream model
@preconcurrency import FirebaseAuth

// Loading and Success Views
struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct SuccessView: View {
    let onDismiss: () -> Void
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheckmark)
            
            Text("Dream Generated!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.small)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            showCheckmark = true
        }
    }
}

extension AudioRecordingService {
    func stopPlaybackPublic() {
        if isPlaying {
            togglePlayback(url: URL(string: "dummy")!) // The URL doesn't matter here since we're only stopping
        }
    }
}

struct ContentView: View {
    @State private var isRecording = false
    @StateObject private var authService = AuthService.shared
    @StateObject private var watchSync = WatchDataSync.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if !watchSync.isReachable {
                    // Show message when iPhone is not reachable
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("Please open Ichiwabi on your iPhone to enable dream recording")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                    }
                } else if authService.currentUserId == nil {
                    // Show message when not signed in
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("Please sign in on your iPhone first")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                    }
                } else {
                    // Main Content when everything is ready
                    RecordButtonView(isRecording: $isRecording)
                }
            }
            .sheet(isPresented: $isRecording) {
                RecordingView(isPresented: $isRecording)
            }
        }
    }
}

struct RecordButtonView: View {
    @Binding var isRecording: Bool
    @State private var isPulsating = false
    @State private var isGlowing = false
    @State private var borderPhase = 0.0
    @State private var isRecordButtonPressed = false
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 20) // Add some padding at the top
            
            // Record Dream Button
            Button {
                WKInterfaceDevice.current().play(.click)
                isRecording = true
            } label: {
                RecordButtonLabel(
                    isPulsating: isPulsating,
                    isGlowing: isGlowing,
                    borderPhase: borderPhase,
                    isPressed: isRecordButtonPressed
                )
            }
            .buttonStyle(
                PressButtonStyle(
                    pressAction: { isPressed in
                        isRecordButtonPressed = isPressed
                        if isPressed {
                            WKInterfaceDevice.current().play(.click)
                        }
                    }
                )
            )
            .onAppear {
                // Start animations
                withAnimation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsating = true
                }
                
                withAnimation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false)
                ) {
                    isGlowing = true
                }
                
                withAnimation(
                    .linear(duration: 30)
                    .repeatForever(autoreverses: false)
                ) {
                    borderPhase = 1.0
                }
            }
            
            Spacer()
                .frame(height: 20) // Add some padding at the bottom
        }
    }
}

struct RecordButtonLabel: View {
    let isPulsating: Bool
    let isGlowing: Bool
    let borderPhase: Double
    let isPressed: Bool
    
    var body: some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 60))
            .frame(width: 140, height: 140)
            .background(
                ZStack {
                    // Base gradient layer
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 244/255, green: 218/255, blue: 248/255),
                            Color(red: 218/255, green: 244/255, blue: 248/255),
                            Color(red: 248/255, green: 228/255, blue: 244/255),
                            Color(red: 244/255, green: 218/255, blue: 248/255)
                        ]),
                        center: .center,
                        angle: .degrees(isPulsating ? 360 : 0)
                    )
                    
                    // Overlay gradient for smoke effect
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.0)
                        ]),
                        center: .init(
                            x: 0.5 + cos(isGlowing ? .pi * 2 : 0) * 0.5,
                            y: 0.5 + sin(isGlowing ? .pi * 2 : 0) * 0.5
                        ),
                        startRadius: 0,
                        endRadius: 100
                    )
                    .blendMode(.plusLighter)
                }
            )
            .foregroundColor(Theme.darkNavy)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.8),
                                Color(red: 0/255, green: 122/255, blue: 255/255),
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0.3)
                            ]),
                            center: .center,
                            angle: .degrees(borderPhase * 360)
                        ),
                        lineWidth: 4
                    )
            )
            .scaleEffect(isPulsating ? 1.05 : 1.0)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6),
                value: isPressed
            )
    }
}

// Add Theme enum for consistency with main app
enum Theme {
    static let darkNavy = Color.black // Using black for watch OS
}

// MARK: - Recording Controls
struct RecordingControls: View {
    let audioService: AudioRecordingService
    let onStopRecording: (URL) -> Void
    
    var body: some View {
        VStack {
            Text(audioService.formattedDuration)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(audioService.isRecording ? 1 : 0)
        }
    }
}

// MARK: - Playback Controls
struct PlaybackControls: View {
    let audioService: AudioRecordingService
    let url: URL
    let title: String?
    let onSave: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    audioService.togglePlayback(url: url)
                }) {
                    Image(systemName: audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                }
                
                if audioService.isPlaying {
                    Text(audioService.formattedPlaybackTime)
                        .font(.system(size: 16))
                }
            }
            
            if let title = title {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack {
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Record Button
struct RecordButton: View {
    let isRecording: Bool
    let audioService: AudioRecordingService
    let onRecordingComplete: (URL) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        Button(action: {
            if isRecording {
                Task {
                    do {
                        if let url = try await audioService.stopRecording() {
                            onRecordingComplete(url)
                        }
                    } catch {
                        onError(error.localizedDescription)
                    }
                }
            } else {
                Task {
                    do {
                        _ = try await audioService.startRecording()
                    } catch {
                        onError(error.localizedDescription)
                    }
                }
            }
        }) {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(isRecording ? .red : .blue)
        }
    }
}

// MARK: - Recording View
struct RecordingView: View {
    @Binding var isPresented: Bool
    @StateObject private var audioService = AudioRecordingService()
    @State private var showError = false
    @State private var recordedAudioURL: URL?
    @State private var isTranscribing = false
    @State private var transcribedText: String?
    @State private var isGeneratingTitle = false
    @State private var generatedTitle: String?
    @State private var isGenerating = false
    @State private var editedTitle = ""
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var selectedStyle: DreamVideoStyle = .realistic
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showSuccess {
                SuccessView {
                    isPresented = false
                }
            } else if isGenerating || isTranscribing {
                LoadingView(message: isTranscribing ? "Transcribing..." : "Generating title...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if audioService.isRecording {
                            RecordingControls(
                                audioService: audioService,
                                onStopRecording: { url in
                                    recordedAudioURL = url
                                    Task { await transcribeAudio(url) }
                                }
                            )
                        } else if let url = recordedAudioURL {
                            PlaybackControls(
                                audioService: audioService,
                                url: url,
                                title: generatedTitle,
                                onSave: {
                                    Task { await handleSave(url) }
                                },
                                onRetry: {
                                    recordedAudioURL = nil
                                    transcribedText = nil
                                    generatedTitle = nil
                                }
                            )
                            .padding(.horizontal)
                            
                            // Dream style selection
                            VStack(spacing: 12) {
                                Text("Dream Style")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 8) {
                                    StyleButton(
                                        title: "Realistic",
                                        systemImage: "photo.fill",
                                        isSelected: selectedStyle == DreamVideoStyle.realistic,
                                        action: { selectedStyle = DreamVideoStyle.realistic }
                                    )
                                    
                                    StyleButton(
                                        title: "Animated",
                                        systemImage: "sparkles",
                                        isSelected: selectedStyle == DreamVideoStyle.animated,
                                        action: { selectedStyle = DreamVideoStyle.animated }
                                    )
                                    
                                    StyleButton(
                                        title: "Cursed",
                                        systemImage: "theatermasks.fill",
                                        isSelected: selectedStyle == DreamVideoStyle.cursed,
                                        action: { selectedStyle = DreamVideoStyle.cursed }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        if recordedAudioURL == nil {
                            RecordButton(
                                isRecording: audioService.isRecording,
                                audioService: audioService,
                                onRecordingComplete: { url in
                                    recordedAudioURL = url
                                    Task { await transcribeAudio(url) }
                                },
                                onError: { error in
                                    errorMessage = error
                                    showError = true
                                }
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func transcribeAudio(_ url: URL) async {
        isTranscribing = true
        defer { isTranscribing = false }
        
        do {
            let apiService = APIService()
            transcribedText = try await apiService.transcribeAudio(fileURL: url)
            await generateTitle()
        } catch {
            print("❌ Transcription failed: \(error)")
            transcribedText = "Failed to transcribe audio: \(error.localizedDescription)"
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    private func generateTitle() async {
        isGeneratingTitle = true
        defer { isGeneratingTitle = false }
        
        guard let transcribedText = transcribedText else {
            generatedTitle = "Untitled Dream"
            return
        }
        
        do {
            let apiService = APIService()
            generatedTitle = try await apiService.generateTitle(dream: transcribedText)
        } catch {
            print("❌ Title generation failed: \(error)")
            // Fallback to timestamp-based title
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, h:mm a"
            generatedTitle = "Dream - \(dateFormatter.string(from: Date()))"
        }
    }
    
    private func handleSave(_ url: URL) async {
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let dreamTitle = generatedTitle ?? "Untitled Dream"
            await saveDream(title: dreamTitle, audioURL: url)
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    private func saveDream(title: String, audioURL: URL) async {
        // Try to get current user ID, sign in anonymously if not signed in
        var userId = AuthService.shared.currentUserId
        if userId == nil {
            do {
                try await AuthService.shared.signInAnonymously()
                userId = AuthService.shared.currentUserId
            } catch {
                errorMessage = "Failed to sign in: \(error.localizedDescription)"
                showError = true
                return
            }
        }
        
        guard let userId = userId else {
            errorMessage = "No user ID found"
            showError = true
            return
        }
        
        let dream = WatchDream(
            userId: userId,
            title: title,
            description: transcribedText ?? "",
            date: Date(),
            audioURL: audioURL,
            localAudioPath: audioURL.lastPathComponent,
            transcript: transcribedText,
            needsUploadToPhone: true,
            videoStyle: selectedStyle
        )
        
        modelContext.insert(dream)
        try? modelContext.save()
        
        // Start sync process
        Task {
            do {
                try await WatchDataSync.shared.syncDream(dream)
            } catch {
                print("Failed to sync dream: \(error)")
                // Error will be handled by WatchDataSync and reflected in dream.watchSyncError
            }
        }
        
        showSuccess = true
    }
}

struct RecordingTimerView: View {
    let duration: TimeInterval
    
    var body: some View {
        Text(timeString(from: duration))
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecordingWaveformView: View {
    let audioLevels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 2)
                    .frame(height: index < audioLevels.count ? audioLevels[index] * 32 : 2)
            }
        }
        .frame(height: 32)
    }
}

struct RecordingControlsView: View {
    let isRecording: Bool
    let onRecordTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: onRecordTap) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(isRecording ? .red : .blue)
            }
            .buttonStyle(.plain)
            
            if isRecording {
                Text("Recording...")
                    .foregroundStyle(.red)
            }
        }
    }
}

struct PressButtonStyle: ButtonStyle {
    let pressAction: (Bool) -> Void
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                pressAction(isPressed)
            }
    }
}

// MARK: - Style Button
struct StyleButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    ContentView()
}
