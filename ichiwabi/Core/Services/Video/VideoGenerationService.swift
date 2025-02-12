import Foundation
import SwiftUI
import AVFoundation

enum VideoGenerationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case videoDownloadFailed
    case processingFailed
    case invalidInput(String)
    case generationTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .videoDownloadFailed:
            return "Failed to download generated video"
        case .processingFailed:
            return "Failed to process generated video"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .generationTimeout:
            return "Video generation timed out"
        }
    }
}

@MainActor
final class VideoGenerationService: ObservableObject {
    private let baseURL = "https://yorutabi-api.vercel.app"
    private let videoProcessingService: VideoProcessingService
    
    @Published private(set) var isGenerating = false
    @Published private(set) var currentStage = GenerationStage.notStarted
    @Published var error: Error?
    
    enum GenerationStage {
        case notStarted
        case requestingAIGeneration
        case waitingForAI
        case downloadingFromAI
        case processingAudio
        case combiningVideoAndAudio
        case applyingWatermark
        case uploadingToCloud
        case completed
        
        var description: String {
            switch self {
            case .notStarted:
                return "Ready to generate"
            case .requestingAIGeneration:
                return "Requesting AI generation..."
            case .waitingForAI:
                return "AI is creating your dream video..."
            case .downloadingFromAI:
                return "Downloading AI-generated video..."
            case .processingAudio:
                return "Processing audio from original dream..."
            case .combiningVideoAndAudio:
                return "Combining video and audio..."
            case .applyingWatermark:
                return "Adding dream details..."
            case .uploadingToCloud:
                return "Saving your dream..."
            case .completed:
                return "Dream generation complete!"
            }
        }
    }
    
    init(videoProcessingService: VideoProcessingService? = nil) {
        self.videoProcessingService = videoProcessingService ?? VideoProcessingService()
    }
    
    func generateVideo(for dream: Dream) async throws -> URL {
        print("\n🎬 ==================== VIDEO GENERATION START ====================")
        print("🎬 Dream ID: \(dream.dreamId)")
        print("🎬 Description: \(dream.dreamDescription)")
        print("🎬 Style: \(dream.videoStyle?.apiStyleName ?? "none")")
        print("🎬 Original video URL: \(dream.videoURL)")
        print("🎬 Local audio path: \(dream.localAudioPath ?? "none")")
        if let audioURL = dream.audioURL {
            print("🎬 Firebase audio URL: \(audioURL)")
        }
        
        isGenerating = true
        error = nil
        currentStage = .requestingAIGeneration
        
        do {
            guard let videoStyle = dream.videoStyle else {
                print("❌ No video style selected")
                throw VideoGenerationError.invalidInput("No video style selected")
            }
            
            // Download audio from Firebase
            guard let firebaseAudioURL = dream.audioURL else {
                print("❌ No Firebase audio URL available")
                throw VideoGenerationError.processingFailed
            }
            
            print("\n🎬 STEP 1: Downloading audio from Firebase")
            print("🎬 Firebase URL: \(firebaseAudioURL)")
            
            // Download the audio file
            let (audioTempURL, audioResponse) = try await URLSession.shared.download(from: firebaseAudioURL)
            
            guard let audioHttpResponse = audioResponse as? HTTPURLResponse,
                  audioHttpResponse.statusCode == 200 else {
                print("❌ Failed to download audio from Firebase")
                throw VideoGenerationError.processingFailed
            }
            
            // Move to a temporary file with .m4a extension
            let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            try? FileManager.default.removeItem(at: audioURL)
            try FileManager.default.moveItem(at: audioTempURL, to: audioURL)
            
            print("✅ Audio downloaded successfully to: \(audioURL)")
            print("✅ Audio file exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
            
            print("🎬 Starting AI video generation for dream: \(dream.dreamId.uuidString)")
            
            // Start generation and get task ID
            print("🎬 Calling startGeneration...")
            let taskId = try await startGeneration(description: dream.dreamDescription, style: videoStyle)
            print("🎬 Received task ID: \(taskId)")
            
            currentStage = .waitingForAI
            
            // Poll for completion
            print("🎬 Starting to wait for completion for task: \(taskId)")
            let replicateVideoURL = try await waitForCompletion(taskId: taskId)
            print("\n🎬 REPLICATE SUCCESS - Video URL: \(replicateVideoURL)")
            
            currentStage = .combiningVideoAndAudio
            print("\n🎬 Combining video and audio")
            print("🎬 Input parameters:")
            print("🎬 - Replicate URL: \(replicateVideoURL)")
            print("🎬 - Audio URL: \(audioURL)")
            print("🎬 - User ID: \(dream.userId)")
            print("🎬 - Dream ID: \(dream.dreamId)")
            print("🎬 - Style: \(videoStyle)")
            print("🎬 - Title: \(dream.title)")
            
            // Process the video using createVideoWithAIAndAudio
            let result = try await videoProcessingService.createVideoWithAIAndAudio(
                replicateVideoURL: replicateVideoURL,
                audioURL: audioURL,
                userId: dream.userId,
                dreamId: dream.dreamId.uuidString,
                style: videoStyle,
                title: dream.title
            )
            
            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            print("\n✅ Video processing completed successfully")
            print("✅ Result:")
            print("✅ - Video URL: \(result.videoURL)")
            print("✅ - Audio URL: \(result.audioURL)")
            print("✅ - Local path: \(result.localPath)")
            
            currentStage = .completed
            isGenerating = false
            
            print("🎬 ==================== VIDEO GENERATION COMPLETE ====================\n")
            return result.videoURL
            
        } catch {
            print("\n❌ ==================== VIDEO GENERATION ERROR ====================")
            print("❌ Error: \(error)")
            if let videoError = error as? VideoGenerationError {
                print("❌ Video Generation Error: \(videoError.errorDescription ?? "Unknown")")
            }
            print("❌ Current stage: \(currentStage.description)")
            print("❌ Stack trace:")
            debugPrint(error)
            print("❌ ==================== END ERROR ====================\n")
            
            isGenerating = false
            self.error = error
            throw error
        }
    }
    
    private func startGeneration(description: String, style: DreamVideoStyle) async throws -> String {
        print("\n🎬 ==================== START GENERATION ====================")
        print("🎬 Base URL: \(baseURL)")
        
        // Create URL with query parameters
        var components = URLComponents(string: "\(baseURL)/generate-video")
        components?.queryItems = [
            URLQueryItem(name: "dream", value: description),
            URLQueryItem(name: "style", value: style.apiStyleName)
        ]
        
        guard let url = components?.url else {
            print("❌ Failed to construct generation URL")
            print("❌ Base URL: \(baseURL)")
            print("❌ Dream description length: \(description.count)")
            print("❌ Style: \(style.apiStyleName)")
            throw VideoGenerationError.invalidURL
        }
        
        print("🎬 Starting video generation with request:")
        print("🎬 - URL: \(url.absoluteString)")
        print("🎬 - Method: POST")
        print("🎬 - Query Parameters:")
        print("🎬   - dream: \(description)")
        print("🎬   - style: \(style.apiStyleName)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        print("🎬 Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("🎬 Received response")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw VideoGenerationError.invalidResponse
        }
        
        print("🎬 Response status code: \(httpResponse.statusCode)")
        print("🎬 Response headers:")
        httpResponse.allHeaderFields.forEach { key, value in
            print("🎬   \(key): \(value)")
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "none"
        print("🎬 Raw response data: \(responseString)")
        print("🎬 Response data length: \(data.count) bytes")
        
        if httpResponse.statusCode != 200 {
            print("❌ Error response: \(responseString)")
            throw VideoGenerationError.apiError("Status \(httpResponse.statusCode): \(responseString)")
        }
        
        do {
            print("🎬 Parsing response JSON...")
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON response")
                throw VideoGenerationError.invalidResponse
            }
            print("🎬 Parsed JSON: \(json)")
            
            // Extract both prediction_id and initial status
            guard let predictionId = json["prediction_id"] as? String else {
                print("❌ Missing prediction_id in response")
                print("❌ Available keys: \(json.keys.joined(separator: ", "))")
                throw VideoGenerationError.invalidResponse
            }
            
            if let initialStatus = json["status"] as? String {
                print("🎬 Initial status: \(initialStatus)")
            }
            
            print("🎬 Found prediction_id: \(predictionId)")
            return predictionId
            
        } catch let jsonError as NSError {
            print("❌ JSON parsing error: \(jsonError.localizedDescription)")
            print("❌ Error domain: \(jsonError.domain)")
            print("❌ Error code: \(jsonError.code)")
            print("❌ Raw response: \(responseString)")
            throw VideoGenerationError.invalidResponse
        }
    }
    
    private func waitForCompletion(taskId: String) async throws -> URL {
        print("\n🎬 ==================== WAIT FOR COMPLETION ====================")
        print("🎬 Prediction ID: \(taskId)")
        
        return try await withTimeout(seconds: 900) { // 15 minutes timeout
            var attempts = 0
            var waitSeconds = 5.0 // Start with 5 seconds
            let maxAttempts = 120
            
            print("🎬 Starting polling loop")
            print("🎬 - Initial wait: \(waitSeconds) seconds")
            print("🎬 - Max attempts: \(maxAttempts)")
            
            while attempts < maxAttempts {
                attempts += 1
                print("\n🎬 Polling attempt \(attempts) of \(maxAttempts)")
                
                let statusEndpoint = "video-status/\(taskId)"
                let fullURL = "\(self.baseURL)/\(statusEndpoint)"
                
                guard let url = URL(string: fullURL) else {
                    throw VideoGenerationError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw VideoGenerationError.invalidResponse
                }
                
                let responseString = String(data: data, encoding: .utf8) ?? "none"
                print("🎬 Response data: \(responseString)")
                
                if httpResponse.statusCode != 200 {
                    throw VideoGenerationError.apiError("Status \(httpResponse.statusCode): \(responseString)")
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw VideoGenerationError.invalidResponse
                }
                print("🎬 Parsed JSON: \(json)")
                
                guard let status = json["status"] as? String else {
                    throw VideoGenerationError.invalidResponse
                }
                
                switch status {
                case "succeeded":
                    guard let output = json["output"] as? String,
                          let videoURL = URL(string: output) else {
                        print("❌ No output URL in response")
                        print("❌ Response: \(json)")
                        throw VideoGenerationError.invalidResponse
                    }
                    print("🎬 Generation succeeded. Video URL: \(videoURL)")
                    return videoURL
                    
                case "failed":
                    let error = json["error"] as? String ?? "Unknown error"
                    throw VideoGenerationError.apiError(error)
                    
                case "starting", "processing":
                    print("🎬 Status: \(status), waiting \(waitSeconds) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
                    waitSeconds = min(waitSeconds * 1.5, 30.0) // Exponential backoff up to 30s
                    
                default:
                    print("⚠️ Unknown status: \(status)")
                    try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
                }
            }
            
            throw VideoGenerationError.generationTimeout
        }
    }
    
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw VideoGenerationError.generationTimeout
            }
            
            // Return the first completed result (or throw the first error)
            guard let result = try await group.next() else {
                throw VideoGenerationError.generationTimeout
            }
            
            // Cancel any remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    private func downloadVideo(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VideoGenerationError.videoDownloadFailed
        }
        
        // Move to a temporary file with .mp4 extension
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let destinationURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func extractAudioFromVideo(at videoURL: URL) async throws -> URL? {
        print("\n🔊 AUDIO EXTRACTION START")
        print("🔊 Source video URL: \(videoURL)")
        print("🔊 Checking if video file exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let audioURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        print("🔊 Target audio URL: \(audioURL)")
        
        // Load the asset
        let asset = AVAsset(url: videoURL)
        
        // Check if asset is playable
        let isPlayable = try await asset.load(.isPlayable)
        print("🔊 Asset is playable: \(isPlayable)")
        
        // Get tracks
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        print("🔊 Number of audio tracks: \(tracks.count)")
        
        // Get duration
        let duration = try await asset.load(.duration)
        print("🔊 Asset duration: \(duration.seconds) seconds")
        
        // Try to get more details about the audio track if available
        if let audioTrack = tracks.first {
            let format = try await audioTrack.load(.formatDescriptions)
            print("🔊 Audio format descriptions: \(String(describing: format))")
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("❌ Failed to create export session")
            return nil
        }
        
        print("🔊 Export session created successfully")
        print("🔊 Supported file types: \(AVAssetExportSession.exportPresets(compatibleWith: asset))")
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = AVFileType.m4a
        exportSession.audioMix = nil
        
        print("🔊 Starting audio export...")
        await exportSession.export()
        
        print("🔊 Export completed with status: \(exportSession.status.rawValue)")
        if let error = exportSession.error {
            print("❌ Export error details:")
            print("❌ - Description: \(error.localizedDescription)")
            let nsError = error as NSError
            print("❌ - Domain: \(nsError.domain)")
            print("❌ - Code: \(nsError.code)")
            print("❌ - User Info: \(nsError.userInfo)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("❌ - Underlying Error Domain: \(underlying.domain)")
                print("❌ - Underlying Error Code: \(underlying.code)")
            }
            return nil
        }
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            print("❌ Export failed with status: \(exportSession.status.rawValue)")
            return nil
        }
        
        print("🔊 Audio extraction completed successfully")
        print("🔊 Output file exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
        print("🔊 ==================== AUDIO EXTRACTION COMPLETE ====================\n")
        return audioURL
    }
}

extension DreamVideoStyle {
    var apiStyleName: String {
        switch self {
        case .realistic:
            return "Realistic"
        case .animated:
            return "Animated"
        case .cursed:
            return "Cursed"
        }
    }
} 