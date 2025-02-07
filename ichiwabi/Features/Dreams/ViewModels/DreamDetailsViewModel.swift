import Foundation
import AVFoundation
import Speech

@MainActor
class DreamDetailsViewModel: ObservableObject {
    private var dreamService: DreamService
    private let userId: String
    private let videoURL: URL
    private let videoUploadService = VideoUploadService()
    
    @Published var title = ""
    @Published var dreamDate = Date()
    @Published var transcript = ""
    @Published var isLoading = false
    @Published var isTranscribing = false
    @Published var error: Error?
    @Published var uploadProgress: Double = 0
    
    init(videoURL: URL, dreamService: DreamService, userId: String, initialTitle: String? = nil) {
        self.videoURL = videoURL
        self.dreamService = dreamService
        self.userId = userId
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
        
        print("💭 Starting dream save process...")
        
        // First upload the video to get both local and cloud URLs
        print("💭 Uploading video...")
        let (localURL, cloudURL) = try await videoUploadService.uploadVideo(
            at: videoURL,
            userId: userId,
            date: dreamDate,
            title: title
        )
        print("💭 Video uploaded successfully")
        print("💭 Local URL: \(localURL)")
        print("💭 Cloud URL: \(cloudURL)")
        
        // Get the relative path for local storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let relativePath = localURL.path(percentEncoded: false)
            .replacingOccurrences(of: documentsPath.path(percentEncoded: false), with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Create and save the dream
        let dream = Dream(
            id: UUID(),
            userId: userId,
            title: title,
            description: transcript,
            date: Date(),
            videoURL: URL(string: cloudURL)!,
            createdAt: Date(),
            updatedAt: Date(),
            transcript: transcript,
            tags: [],
            category: nil,
            isSynced: false,
            lastSyncedAt: nil,
            dreamDate: dreamDate,
            localVideoPath: relativePath
        )
        
        print("💭 Saving dream to database...")
        try await dreamService.saveDream(dream)
        print("💭 Dream saved successfully")
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