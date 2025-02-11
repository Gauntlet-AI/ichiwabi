import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var isPlaying = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var audioLevels: [CGFloat] = []
    @Published var errorMessage: String?
    @Published private(set) var recordedLevels: [CGFloat] = []
    @Published private(set) var displayLevels: [CGFloat] = []
    
    // MARK: - Constants
    static let maxDuration: TimeInterval = 64 // 64 seconds
    private let sampleCount = 50 // Number of samples to show in waveform
    private let audioLevelUpdateInterval: TimeInterval = 0.05 // 50ms
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    
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
        isPaused = false
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
        isPaused = false
        recordingDuration = 0
        
        return recordingURL
    }
    
    // MARK: - Playback Methods
    func startPlayback(url: URL) async throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            displayLevels = recordedLevels
            
            // Start timer for current time and waveform updates
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self, let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }
                self.currentTime = player.currentTime
                
                // Update displayed levels based on playback position
                let progress = player.currentTime / player.duration
                let levelIndex = Int(progress * Double(self.recordedLevels.count))
                
                // Safely get a window of levels
                let startIndex = max(0, min(levelIndex, self.recordedLevels.count - 1))
                let endIndex = min(startIndex + self.sampleCount, self.recordedLevels.count)
                if startIndex < endIndex {
                    self.audioLevels = Array(self.recordedLevels[startIndex..<endIndex])
                } else {
                    self.audioLevels = []
                }
            }
        } catch {
            throw AudioRecordingError.playbackFailed
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        audioLevels = []
    }
    
    func togglePlayback(url: URL) {
        if isPlaying {
            stopPlayback()
        } else {
            Task {
                try await startPlayback(url: url)
            }
        }
    }
    
    func togglePause() {
        guard isRecording else { return }
        
        if isPaused {
            // Resume recording
            audioRecorder?.record()
            isPaused = false
            startTimers()
            print("📼 Resumed recording")
        } else {
            // Pause recording
            audioRecorder?.pause()
            isPaused = true
            stopTimers()
            print("📼 Paused recording")
        }
    }
    
    // MARK: - Timer Management
    private func startTimers() {
        stopTimers() // Ensure any existing timers are cleaned up
        
        // Recording duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime,
                  !self.isPaused else { return }
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordingDuration = duration
            
            // Stop recording if max duration reached
            if duration >= Self.maxDuration {
                Task {
                    try await self.stopRecording()
                }
            }
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: audioLevelUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recorder = self.audioRecorder,
                  !self.isPaused else { return }
            
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            
            // Convert dB to normalized value (0-1)
            let minDb: Float = -60
            let normalizedValue = max(0, (level - minDb) / abs(minDb))
            
            // Add to levels array
            DispatchQueue.main.async {
                let value = CGFloat(normalizedValue)
                self.audioLevels.append(value)
                self.recordedLevels.append(value)
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
    func cleanup() {
        stopPlayback()
        stopTimers()
        audioRecorder?.stop()
        audioRecorder = nil
        recordingURL = nil
        audioLevels.removeAll()
        recordedLevels.removeAll()
        displayLevels.removeAll()
        recordingDuration = 0
        currentTime = 0
        isRecording = false
        isPaused = false
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            if !flag {
                self.errorMessage = "Recording failed to complete"
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.errorMessage = error?.localizedDescription ?? "Recording failed"
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
        }
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