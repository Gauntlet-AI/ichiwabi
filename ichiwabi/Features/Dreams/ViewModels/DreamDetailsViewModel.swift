import Foundation
import AVFoundation
import Speech

@MainActor
final class DreamDetailsViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var transcript: String = ""
    @Published var dreamDate: Date
    @Published private(set) var isTranscribing = false
    @Published private(set) var isLoading = false
    @Published private(set) var uploadProgress: Double = 0
    @Published var error: Error?
    
    let videoURL: URL
    private let dreamService: DreamService
    private let uploadService: VideoUploadService
    private let userId: String
    
    init(videoURL: URL, dreamService: DreamService, userId: String) {
        self.videoURL = videoURL
        self.dreamService = dreamService
        self.uploadService = VideoUploadService()
        self.userId = userId
        self.dreamDate = Calendar.current.startOfDay(for: Date())
        
        Task {
            await transcribeVideo()
        }
    }
    
    func saveDream() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Upload video first
            let videoURLString = try await uploadService.uploadVideo(
                at: videoURL,
                userId: userId
            )
            
            // Update upload progress
            uploadProgress = uploadService.uploadProgress
            
            // Create dream with video URL
            let dream = try await dreamService.createDream(
                title: title,
                dreamDate: dreamDate
            )
            
            // Update dream with transcript and video URL
            dream.transcript = transcript
            dream.videoURL = videoURLString
            try await dreamService.updateDream(dream)
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    private func transcribeVideo() async {
        isTranscribing = true
        defer { isTranscribing = false }
        
        // Request transcription authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            
            guard granted else {
                error = DreamDetailsError.transcriptionNotAuthorized
                return
            }
        }
        
        // Create recognizer
        guard let recognizer = SFSpeechRecognizer() else {
            error = DreamDetailsError.transcriptionNotAvailable
            return
        }
        
        guard recognizer.isAvailable else {
            error = DreamDetailsError.transcriptionNotAvailable
            return
        }
        
        // Create recognition request
        let asset = AVAsset(url: videoURL)
        guard (try? await asset.loadTracks(withMediaType: .audio).first) != nil else {
            error = DreamDetailsError.noAudioTrack
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: videoURL)
        request.shouldReportPartialResults = true
        
        // Start recognition
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result {
                        continuation.resume(returning: result)
                    }
                }
            }
            
            self.transcript = result.bestTranscription.formattedString
        } catch {
            self.error = error
        }
    }
}

// MARK: - Errors

enum DreamDetailsError: LocalizedError {
    case transcriptionNotAuthorized
    case transcriptionNotAvailable
    case noAudioTrack
    
    var errorDescription: String? {
        switch self {
        case .transcriptionNotAuthorized:
            return "Speech recognition is not authorized"
        case .transcriptionNotAvailable:
            return "Speech recognition is not available on this device"
        case .noAudioTrack:
            return "No audio track found in the video"
        }
    }
} 