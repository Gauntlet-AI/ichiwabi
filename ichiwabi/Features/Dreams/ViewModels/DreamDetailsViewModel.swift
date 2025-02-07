import Foundation
import AVFoundation
import Speech

@MainActor
class DreamDetailsViewModel: ObservableObject {
    private var dreamService: DreamService
    private let userId: String
    private let videoURL: URL
    private let videoUploadService = VideoUploadService()
    private let trimStartTime: Double
    private let trimEndTime: Double
    
    @Published var title = ""
    @Published var dreamDate = Date()
    @Published var transcript = ""
    @Published var isLoading = false
    @Published var isTranscribing = false
    @Published var error: Error?
    @Published var uploadProgress: Double = 0
    
    init(videoURL: URL, dreamService: DreamService, userId: String, initialTitle: String? = nil, trimStartTime: Double = 0, trimEndTime: Double = 0) {
        self.videoURL = videoURL
        self.dreamService = dreamService
        self.userId = userId
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        if let initialTitle = initialTitle {
            self.title = initialTitle
        }
        
        // Start transcription when initialized
        Task {
            await transcribeVideo()
        }
    }
    
    func updateDreamService(_ newService: DreamService) {
        self.dreamService = newService
    }
    
    func saveDream() async throws {
        isLoading = true
        defer { isLoading = false }
        
        print("💭 Starting video save process...")
        
        let asset = AVAsset(url: videoURL)
        print("💭 Original video URL: \(videoURL.path)")
        
        // Verify original asset is playable
        let isOriginalPlayable = try await asset.load(.isPlayable)
        print("💭 Original asset playable: \(isOriginalPlayable)")
        
        // Get tracks info
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        print("💭 Original video tracks: \(videoTracks.count), audio tracks: \(audioTracks.count)")
        
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "DreamDetailsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        print("💭 Original video natural size: \(naturalSize), transform: \(transform)")
        
        // Since the video is already trimmed, we'll use it directly
        let assetDuration = try await asset.load(.duration)
        print("💭 Using pre-trimmed video with duration: \(assetDuration.seconds) seconds")
        
        // Upload the video directly to cloud storage
        let (localURL, cloudURL) = try await videoUploadService.uploadVideo(
            at: videoURL,
            userId: userId,
            date: dreamDate,
            title: title
        )
        
        // Create dream with trim points set to 0 since video is already trimmed
        let dream = Dream(
            userId: userId,
            title: title,
            description: transcript,
            date: Date(),
            videoURL: URL(string: cloudURL)!,
            transcript: transcript,
            dreamDate: dreamDate,
            localVideoPath: localURL.lastPathComponent,
            trimStartTime: 0,
            trimEndTime: 0
        )
        
        // Save dream to local storage and sync
        try await dreamService.saveDream(dream)
        
        print("💭 Dream saved successfully")
        
        // Post notification to refresh home view
        NotificationCenter.default.post(name: NSNotification.Name("DismissVideoTrimmer"), object: nil)
    }
    
    private func transcribeVideo() async {
        guard !isTranscribing else { return }
        isTranscribing = true
        defer { isTranscribing = false }
        
        do {
            let asset = AVAsset(url: videoURL)
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                return
            }
            
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
            guard recognizer.isAvailable else {
                throw NSError(domain: "Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is not available"])
            }
            
            let request = SFSpeechURLRecognitionRequest(url: videoURL)
            request.shouldReportPartialResults = false
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                recognizer.recognitionTask(with: request) { [weak self] result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let result = result else {
                        continuation.resume()
                        return
                    }
                    
                    if result.isFinal {
                        Task { @MainActor [weak self] in
                            self?.transcript = result.bestTranscription.formattedString
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            print("❌ Transcription error: \(error.localizedDescription)")
            // Don't show error to user - transcription is optional
        }
    }
}

// MARK: - Errors

enum DreamDetailsError: LocalizedError {
    case transcriptionNotAuthorized
    case transcriptionNotAvailable
    case noAudioTrack
    case videoUploadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .transcriptionNotAuthorized:
            return "Speech recognition is not authorized"
        case .transcriptionNotAvailable:
            return "Speech recognition is not available on this device"
        case .noAudioTrack:
            return "No audio track found in the video"
        case .videoUploadFailed(let error):
            return "Failed to upload video: \(error.localizedDescription)"
        }
    }
} 