import Foundation
import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseFirestore

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
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
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
    
    func generateVideo(for dream: Dream) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        print("\n🎬 ==================== VIDEO GENERATION ====================")
        print("🎬 Starting video generation for dream: \(dream.id)")
        
        do {
            // 1. Download the audio file
            guard let audioURL = dream.audioURL?.absoluteString else {
                throw NSError(domain: "VideoGeneration", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid audio URL"
                ])
            }
            
            let audioData = try await downloadFile(from: URL(string: audioURL)!)
            let localAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            try audioData.write(to: localAudioURL)
            print("✅ Audio downloaded successfully")
            
            // 2. Generate video frames based on style and description
            let videoFrames = try await generateVideoFrames(
                description: dream.dreamDescription,
                style: dream.videoStyle ?? .realistic
            )
            print("✅ Video frames generated successfully")
            
            // 3. Combine audio and video frames
            let outputURL = try await combineAudioAndVideo(
                audioURL: localAudioURL,
                videoFrames: videoFrames,
                outputFileName: "\(dream.dreamId.uuidString).mp4"
            )
            print("✅ Audio and video combined successfully")
            
            // 4. Upload the final video
            let videoRef = storage.reference().child("users/\(dream.userId)/videos/\(dream.dreamId.uuidString).mp4")
            _ = try await videoRef.putFile(from: outputURL)
            let videoDownloadURL = try await videoRef.downloadURL()
            print("✅ Video uploaded successfully")
            
            // 5. Update Firestore document
            try await db.collection("dreams").document(dream.dreamId.uuidString).updateData([
                "videoURL": videoDownloadURL.absoluteString,
                "status": "completed",
                "isProcessing": false,
                "processingProgress": 1.0,
                "processingStatus": "completed",
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Firestore document updated")
            
            // 6. Clean up temporary files
            try? FileManager.default.removeItem(at: localAudioURL)
            try? FileManager.default.removeItem(at: outputURL)
            print("✅ Temporary files cleaned up")
            
            print("🎬 ==================== END GENERATION ====================\n")
            return videoDownloadURL.absoluteString
            
        } catch {
            print("❌ Video generation failed: \(error.localizedDescription)")
            
            // Update Firestore with error status
            try? await db.collection("dreams").document(dream.dreamId.uuidString).updateData([
                "status": "failed",
                "isProcessing": false,
                "processingStatus": "failed",
                "processingError": error.localizedDescription,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            throw error
        }
    }
    
    private func downloadFile(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    private func generateVideoFrames(description: String, style: DreamVideoStyle) async throws -> [CGImage] {
        // TODO: Implement video frame generation using your AI service
        // For now, return a placeholder frame
        let placeholderFrame = try generatePlaceholderFrame(text: "Dream Video")
        return Array(repeating: placeholderFrame, count: 30) // 1 second at 30fps
    }
    
    private func generatePlaceholderFrame(text: String) throws -> CGImage {
        let size = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Fill background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "VideoGeneration", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create placeholder frame"
            ])
        }
        
        return cgImage
    }
    
    private func combineAudioAndVideo(
        audioURL: URL,
        videoFrames: [CGImage],
        outputFileName: String
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create video writer
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw NSError(domain: "VideoGeneration", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create video writer"
            ])
        }
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoFrames[0].width,
            AVVideoHeightKey: videoFrames[0].height
        ]
        
        // Create video input
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        
        // Create pixel buffer adapter
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoFrames[0].width,
            kCVPixelBufferHeightKey as String: videoFrames[0].height
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: attributes
        )
        
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriter.add(videoWriterInput)
        
        // Start writing session
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // Write video frames
        let frameDuration = CMTime(value: 1, timescale: 30) // 30fps
        var frameCount: Int64 = 0
        
        for frame in videoFrames {
            while !videoWriterInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            let presentationTime = CMTime(value: frameCount, timescale: 30)
            
            autoreleasepool {
                if let pixelBuffer = createPixelBuffer(from: frame, attributes: attributes) {
                    try? pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                }
            }
            
            frameCount += 1
        }
        
        // Finish writing video
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return outputURL
    }
    
    private func createPixelBuffer(from image: CGImage, attributes: [String: Any]) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixelBuffer
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
    
    @MainActor
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
        print("🔊 Available export presets:")
        print("🔊 - High Quality: \(AVAssetExportPresetHighestQuality)")
        print("🔊 - Medium Quality: \(AVAssetExportPresetMediumQuality)")
        print("🔊 - Low Quality: \(AVAssetExportPresetLowQuality)")
        print("🔊 - Audio Only: \(AVAssetExportPresetAppleM4A)")
        
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
