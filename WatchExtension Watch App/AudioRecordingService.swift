import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class AudioRecordingService: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var audioLevels: [CGFloat] = []
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        formatTime(recordingDuration)
    }
    
    var formattedPlaybackTime: String {
        formatTime(currentTime)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Constants
    static let maxDuration: TimeInterval = 60 // 60 seconds for watch
    private let sampleCount = 20 // Reduced sample count for watch UI
    private let audioLevelUpdateInterval: TimeInterval = 0.1
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var playbackTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Recording Methods
    func startRecording() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                // Create temporary URL for recording
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(UUID().uuidString).m4a"
                let tempURL = tempDir.appendingPathComponent(fileName)
                
                // Configure recording settings
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                // Create and configure recorder
                audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = true
                
                guard audioRecorder?.record() == true else {
                    throw AudioRecordingError.recordingFailed
                }
                
                recordingURL = tempURL
                isRecording = true
                recordingStartTime = Date()
                startTimers()
                
                continuation.resume(returning: tempURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func stopRecording() async throws -> URL? {
        guard let recorder = audioRecorder, isRecording else {
            throw AudioRecordingError.notRecording
        }
        
        recorder.stop()
        stopTimers()
        isRecording = false
        recordingDuration = 0
        
        return recordingURL
    }
    
    // MARK: - Playback Methods
    func togglePlayback(url: URL) {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback(url: url)
        }
    }
    
    private func startPlayback(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            
            // Start timer to update currentTime
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                
                // Simulate audio levels during playback
                let randomLevel = Double.random(in: 0.1...0.8)
                self.audioLevels.append(randomLevel)
                if self.audioLevels.count > self.sampleCount {
                    self.audioLevels.removeFirst()
                }
            }
        } catch {
            errorMessage = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        currentTime = 0
        audioLevels.removeAll()
    }
    
    // MARK: - Timer Management
    private func startTimers() {
        stopTimers()
        
        // Recording duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let startTime = self.recordingStartTime else { return }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordingDuration = duration
                
                // Stop recording if max duration reached
                if duration >= Self.maxDuration {
                    do {
                        _ = try await self.stopRecording()
                    } catch {
                        self.errorMessage = "Failed to stop recording: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: audioLevelUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let recorder = self.audioRecorder else { return }
                
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                
                // Convert dB to normalized value (0-1)
                let minDb: Float = -60
                let normalizedValue = max(0, (level - minDb) / abs(minDb))
                
                // Add to levels array
                let value = CGFloat(normalizedValue)
                self.audioLevels.append(value)
                if self.audioLevels.count > self.sampleCount {
                    self.audioLevels.removeFirst()
                }
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    // MARK: - Cleanup
    func cleanup() async {
        if isRecording {
            do {
                _ = try await stopRecording()
            } catch {
                // We'll just log the error since cleanup is typically called during teardown
                print("Error stopping recording during cleanup: \(error)")
            }
        }
        stopPlayback()
    }
    
    // AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            if !flag {
                self.errorMessage = "Recording failed to complete"
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.errorMessage = error?.localizedDescription ?? "Recording failed"
        }
    }
    
    // AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            errorMessage = "Playback error: \(error.localizedDescription)"
        }
        stopPlayback()
    }
}

// MARK: - Errors
enum AudioRecordingError: LocalizedError {
    case recordingFailed
    case notRecording
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to start recording"
        case .notRecording:
            return "No active recording"
        case .playbackFailed:
            return "Failed to play audio"
        }
    }
} 