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
        case generatingVideo
        case downloadingVideo
        case processingVideo
        case applyingAudio
        case finishing
        case completed
        
        var description: String {
            switch self {
            case .notStarted:
                return "Ready to generate"
            case .generatingVideo:
                return "Generating your dream..."
            case .downloadingVideo:
                return "Downloading video..."
            case .processingVideo:
                return "Processing video..."
            case .applyingAudio:
                return "Adding audio..."
            case .finishing:
                return "Applying finishing touches..."
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
        
        isGenerating = true
        error = nil
        currentStage = .generatingVideo
        
        do {
            guard let videoStyle = dream.videoStyle else {
                print("❌ No video style selected")
                throw VideoGenerationError.invalidInput("No video style selected")
            }
            
            // Store the original video URL before we start
            let originalVideoURL = dream.videoURL
            print("🎬 Original video URL: \(originalVideoURL)")
            
            print("🎬 Starting AI video generation for dream: \(dream.dreamId.uuidString)")
            
            // Start generation and get task ID
            print("🎬 Calling startGeneration...")
            let taskId = try await startGeneration(description: dream.dreamDescription, style: videoStyle)
            print("🎬 Received task ID: \(taskId)")
            
            // Add a small delay to allow the task to be registered
            print("🎬 Waiting 2 seconds before starting to poll...")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Poll for completion
            print("🎬 Starting to wait for completion for task: \(taskId)")
            let replicateVideoURL = try await waitForCompletion(taskId: taskId)
            
            print("🎬 Video generated successfully at URL: \(replicateVideoURL)")
            currentStage = .downloadingVideo
            
            // Download the new video from Replicate
            let downloadedReplicateVideo = try await downloadVideo(from: replicateVideoURL)
            print("🎬 Replicate video downloaded successfully to: \(downloadedReplicateVideo)")
            
            currentStage = .processingVideo
            
            // Extract audio from the original video
            guard let audioURL = try await extractAudioFromVideo(at: originalVideoURL) else {
                print("❌ Failed to extract audio from original video")
                throw VideoGenerationError.processingFailed
            }
            print("🎬 Audio extracted successfully to: \(audioURL)")
            
            // Get audio duration
            let audioAsset = AVAsset(url: audioURL)
            let audioDuration = try await audioAsset.load(.duration).seconds
            print("🎬 Audio duration: \(audioDuration) seconds")
            
            currentStage = .applyingAudio
            
            // Process the downloaded Replicate video
            let processedVideoURL = try await videoProcessingService.processAndUploadVideo(
                videoURL: downloadedReplicateVideo,
                audioURL: audioURL,
                userId: dream.userId,
                dreamId: dream.dreamId.uuidString,
                style: videoStyle,
                title: dream.title
            )
            print("🎬 Video processed and uploaded successfully")
            
            currentStage = .finishing
            
            try? FileManager.default.removeItem(at: downloadedReplicateVideo)
            try? FileManager.default.removeItem(at: audioURL)
            print("🎬 Temporary files cleaned up")
            
            currentStage = .completed
            isGenerating = false
            
            print("🎬 ==================== VIDEO GENERATION COMPLETE ====================\n")
            return processedVideoURL.videoURL
            
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
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let audioURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        let asset = AVAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            return nil
        }
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = AVFileType.m4a
        exportSession.audioMix = nil
        
        await exportSession.export()
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            return nil
        }
        
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