import Foundation
import AVFoundation
import CoreMedia
import UIKit
import SwiftUI
import FirebaseStorage

@MainActor
final class VideoProcessingService: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published var error: Error?
    
    private let watermarkService = WatermarkService.shared
    private let assetService: VideoAssetService
    private let storage: Storage
    
    init(assetService: VideoAssetService = VideoAssetService()) {
        self.assetService = assetService
        self.storage = Storage.storage()
    }
    
    enum VideoQuality {
        case high
        case medium
        case low
        
        var preset: String {
            switch self {
            case .high:
                return AVAssetExportPreset1920x1080
            case .medium:
                return AVAssetExportPreset1280x720
            case .low:
                return AVAssetExportPreset960x540
            }
        }
        
        var bitrateMultiplier: Float {
            switch self {
            case .high:
                return 1.0
            case .medium:
                return 0.7
            case .low:
                return 0.5
            }
        }
    }
    
    private func performExport(
        _ exportSession: AVAssetExportSession
    ) async throws {
        // Create a continuation to track the export status
        let status = try await withCheckedThrowingContinuation { continuation in
            // Since we're @MainActor-isolated, this runs on the main thread
            exportSession.exportAsynchronously { [weak exportSession] in
                // Capture the status immediately
                let status = exportSession?.status ?? .failed
                let error = exportSession?.error
                
                // Resume on main actor to safely handle the result
                Task { @MainActor in
                    switch status {
                    case .completed:
                        self.progress = 1.0
                        continuation.resume(returning: status)
                    case .failed:
                        print("Export failed with error: \(String(describing: error))")
                        continuation.resume(throwing: error ?? VideoProcessingError.exportFailed)
                    case .cancelled:
                        continuation.resume(throwing: VideoProcessingError.exportCancelled)
                    default:
                        continuation.resume(throwing: VideoProcessingError.unknown)
                    }
                }
            }
            
            // Track progress
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak exportSession] _ in
                Task { @MainActor [weak self] in
                    guard let progress = exportSession?.progress else { return }
                    self?.progress = Double(progress)
                }
            }
            
            // Ensure timer is invalidated when export completes
            Task {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.main.async {
                        progressTimer.invalidate()
                        continuation.resume()
                    }
                }
            }
        }
        
        // Verify the status
        guard status == .completed else {
            throw VideoProcessingError.exportFailed
        }
    }
    
    private func configureExportSession(
        asset: AVAsset,
        outputURL: URL,
        quality: VideoQuality
    ) throws -> AVAssetExportSession {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        return exportSession
    }
    
    func trimVideo(
        at videoURL: URL,
        from startTime: Double,
        to endTime: Double,
        date: Date,
        title: String?
    ) async throws -> URL {
        isProcessing = true
        progress = 0
        
        defer {
            isProcessing = false
        }
        
        print("\n✂️ Starting video trim process")
        print("✂️ Input video: \(videoURL)")
        print("✂️ Trim range: \(startTime) to \(endTime) seconds")
        
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        
        // Log input video details
        let tracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            let size = try await videoTrack.load(.naturalSize)
            let bitrate = try await videoTrack.load(.estimatedDataRate)
            let framerate = try await videoTrack.load(.nominalFrameRate)
            print("\n📊 Input Video Details:")
            print("📊 - Dimensions: \(size)")
            print("📊 - Bitrate: \(bitrate) bps")
            print("📊 - Frame Rate: \(framerate) fps")
            print("📊 - Duration: \(duration) seconds")
        }
        
        // Validate time range
        let validatedStart = max(0, min(startTime, duration))
        let validatedEnd = max(validatedStart + 1, min(endTime, duration))
        print("✂️ Validated trim range: \(validatedStart) to \(validatedEnd) seconds")
        
        // Create temporary URL for trimmed video
        let trimmedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_dream_\(UUID().uuidString).mp4")
        
        // Configure export session
        let exportSession = try configureExportSession(
            asset: asset,
            outputURL: trimmedURL,
            quality: .high
        )
        
        // Set time range
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: validatedStart, preferredTimescale: 600),
            end: CMTime(seconds: validatedEnd, preferredTimescale: 600)
        )
        
        // Add watermark
        let videoComposition = try await watermarkService.applyWatermark(
            to: asset,
            date: date,
            title: title
        )
        exportSession.videoComposition = videoComposition
        
        // Export the video
        print("\n🎥 Starting video export...")
        try await performExport(exportSession)
        
        print("✅ Export completed with status: \(exportSession.status.rawValue)")
        
        // Log output video details
        if FileManager.default.fileExists(atPath: trimmedURL.path) {
            let trimmedAsset = AVAsset(url: trimmedURL)
            let trimmedTracks = try await trimmedAsset.loadTracks(withMediaType: .video)
            if let trimmedTrack = trimmedTracks.first {
                let size = try await trimmedTrack.load(.naturalSize)
                let bitrate = try await trimmedTrack.load(.estimatedDataRate)
                let framerate = try await trimmedTrack.load(.nominalFrameRate)
                print("\n📊 Output Video Details:")
                print("📊 - Dimensions: \(size)")
                print("📊 - Bitrate: \(bitrate) bps")
                print("📊 - Frame Rate: \(framerate) fps")
                print("📊 - File Size: \(try FileManager.default.attributesOfItem(atPath: trimmedURL.path)[.size] ?? 0) bytes")
            }
        }
        
        return trimmedURL
    }
    
    @MainActor
    private func createWatermarkImage(date: Date, size: CGSize) throws -> UIImage {
        // Create the watermark image on the main thread
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create a hosting controller for the watermark view
            let watermarkView = WatermarkView(
                date: date,
                title: nil  // We'll add the title when saving the dream
            )
            let hostingController = UIHostingController(rootView: watermarkView)
            hostingController.view.backgroundColor = .clear
            
            // Size the hosting view - make it smaller (30% width instead of 40%)
            let watermarkSize = CGSize(width: size.width * 0.3, height: size.height * 0.12)
            hostingController.view.frame = CGRect(
                x: size.width - watermarkSize.width - 20,  // Position from right edge
                y: size.height - watermarkSize.height - 20,
                width: watermarkSize.width,
                height: watermarkSize.height
            )
            
            // Render the view
            hostingController.view.drawHierarchy(
                in: hostingController.view.bounds,
                afterScreenUpdates: true
            )
        }
        
        return image
    }
    
    private func createWatermarkedComposition(for asset: AVAsset, date: Date) async throws -> AVMutableVideoComposition {
        print("🎨 Starting watermarked composition")
        let composition = AVMutableVideoComposition(asset: asset) { [weak self] request in
            guard let self = self else {
                print("🎨 Self is nil, using source image")
                request.finish(with: request.sourceImage, context: nil)
                return
            }
            
            Task { @MainActor in
                do {
                    // Create the watermark image on the main actor
                    let watermarkImage = try self.createWatermarkImage(date: date, size: request.renderSize)
                    
                    // Render the original video frame
                    let image = request.sourceImage
                    
                    // If we have a watermark, composite it over the video frame
                    if let watermark = CIImage(image: watermarkImage)?.transformed(by: CGAffineTransform(
                        translationX: 20,
                        y: 20
                    )) {
                        let result = image.composited(over: watermark)
                        request.finish(with: result, context: nil)
                    } else {
                        print("🎨 No watermark available, using original frame")
                        request.finish(with: image, context: nil)
                    }
                } catch {
                    print("🎨 Failed to create watermark: \(error)")
                    request.finish(with: request.sourceImage, context: nil)
                }
            }
        }
        
        print("🎨 Watermarked composition created")
        return composition
    }
    
    private func createVideoComposition(for asset: AVAsset) async -> AVMutableVideoComposition {
        // Create video composition
        let videoComposition = AVMutableVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            // Apply any additional processing here if needed
            request.finish(with: request.sourceImage, context: nil)
        })
        
        // Ensure video is in portrait orientation
        if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
            let size = try? await videoTrack.load(.naturalSize)
            if let size = size {
                videoComposition.renderSize = CGSize(width: min(size.width, size.height),
                                                   height: max(size.width, size.height))
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            }
        }
        
        return videoComposition
    }
    
    private func calculateBitrate(for asset: AVAsset, quality: VideoQuality) async -> Int {
        // Base bitrate calculation
        let tracks = try? await asset.load(.tracks)
        
        guard let videoTrack = tracks?.first(where: { $0.mediaType == .video }) else {
            return 2_000_000 // Default to 2 Mbps if we can't calculate
        }
        
        let size = try? await videoTrack.load(.naturalSize)
        let frameRate = try? await videoTrack.load(.nominalFrameRate)
        
        let width = size?.width ?? 1920
        let height = size?.height ?? 1080
        let fps = frameRate ?? 30
        
        // Calculate bitrate based on resolution and frame rate
        let pixelsPerFrame = width * height
        let bitsPerPixel: Float = 0.1 // Adjust this value to change quality
        let baseBitrate = Float(pixelsPerFrame) * bitsPerPixel * Float(fps)
        
        // Apply quality multiplier
        let adjustedBitrate = Int(baseBitrate * quality.bitrateMultiplier)
        
        // Ensure bitrate is within reasonable bounds
        return min(max(adjustedBitrate, 1_000_000), 8_000_000)
    }
    
    @MainActor
    private func handleExportResult(
        _ exportSession: AVAssetExportSession,
        outputURL: URL
    ) throws -> URL {
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            print("Export failed with error: \(String(describing: exportSession.error))")
            throw exportSession.error ?? VideoProcessingError.exportFailed
        case .cancelled:
            throw VideoProcessingError.exportCancelled
        default:
            throw VideoProcessingError.unknown
        }
    }
    
    func processAndUploadVideo(
        videoURL: URL? = nil,  // Optional parameter for AI-generated video
        audioURL: URL,
        userId: String,
        dreamId: String,
        style: DreamVideoStyle,
        title: String? = nil
    ) async throws -> (videoURL: URL, audioURL: URL, localPath: String) {
        print("\n🚨 ENTRY POINT: processAndUploadVideo")
        print("🚨 Parameters:")
        print("🚨 - videoURL: \(videoURL?.absoluteString ?? "none")")
        print("🚨 - audioURL: \(audioURL.absoluteString)")
        print("🚨 - userId: \(userId)")
        print("🚨 - dreamId: \(dreamId)")
        print("🚨 - style: \(style)")
        print("🚨 - title: \(title ?? "none")")
        
        // First, upload the audio file to Firebase Storage
        let audioRef = storage.reference().child("users/\(userId)/audio/\(dreamId).m4a")
        let audioMetadata = StorageMetadata()
        audioMetadata.contentType = "audio/m4a"
        
        print("🎬 Uploading audio file to Firebase Storage")
        _ = try await audioRef.putFileAsync(from: audioURL, metadata: audioMetadata)
        let audioDownloadURL = try await audioRef.downloadURL()
        print("🎬 Audio file uploaded successfully: \(audioDownloadURL)")
        
        // Create an asset from the audio file
        let audioAsset = AVAsset(url: audioURL)
        let audioDuration = try await audioAsset.load(.duration).seconds
        print("🎬 Audio duration: \(audioDuration) seconds")
        
        // Get the video to process (either AI-generated or default)
        let processedVideoURL: URL
        if let aiVideoURL = videoURL {
            // Use the AI-generated video directly
            processedVideoURL = aiVideoURL
            print("🎬 Using AI-generated video")
        } else {
            // Create default video with audio
            processedVideoURL = try await assetService.createVideoWithAudio(
                audioURL: audioURL,
                duration: audioDuration,
                style: style
            )
            print("🎬 Created default video")
        }
        
        // STEP 1: Create a composition with video and audio
        print("\n🎬 STEP 1: Creating video/audio composition")
        let composition = AVMutableComposition()
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ Failed to create video track")
            throw VideoProcessingError.invalidAsset
        }
        
        // Add audio track
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ Failed to create audio track")
            throw VideoProcessingError.invalidAsset
        }
        
        // Get source tracks
        let videoAsset = AVAsset(url: processedVideoURL)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        
        guard let sourceVideoTrack = videoTracks.first else {
            print("❌ No video track in source")
            throw VideoProcessingError.invalidAsset
        }
        
        guard let sourceAudioTrack = audioTracks.first else {
            print("❌ No audio track in source")
            throw VideoProcessingError.invalidAsset
        }
        
        // Insert audio for its duration
        let audioTimeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: audioDuration, preferredTimescale: 600)
        )
        try compositionAudioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
        print("✅ Audio track inserted")
        
        // Loop video to match audio duration
        var currentTime = CMTime.zero
        let videoDuration = try await videoAsset.load(.duration)
        
        while currentTime < audioTimeRange.duration {
            let remainingTime = audioTimeRange.duration - currentTime
            let insertDuration = min(remainingTime, videoDuration)
            
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: insertDuration),
                of: sourceVideoTrack,
                at: currentTime
            )
            
            currentTime = CMTimeAdd(currentTime, insertDuration)
        }
        print("✅ Video track inserted")
        
        // STEP 2: Export to intermediate file
        print("\n🎬 STEP 2: Exporting composition to intermediate file")
        let intermediateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("intermediate_\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
        ) else {
            print("❌ Failed to create export session")
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = intermediateURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Use appropriate audio settings based on iOS version
        if #available(iOS 15.0, *) {
            exportSession.audioTimePitchAlgorithm = .timeDomain
        } else {
            exportSession.audioTimePitchAlgorithm = .lowQualityZeroLatency
        }
        
        print("🎬 Exporting intermediate file...")
        await exportSession.export()
        
        if exportSession.status != .completed {
            print("❌ Intermediate export failed with status: \(exportSession.status.rawValue)")
            if let error = exportSession.error {
                print("❌ Export error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                let nsError = error as NSError
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("❌ Underlying error domain: \(underlying.domain)")
                    print("❌ Underlying error code: \(underlying.code)")
                }
            }
            throw VideoProcessingError.exportFailed
        }
        
        // STEP 3: Add watermark to the intermediate file
        print("\n🎬 STEP 3: Adding watermark")
        let watermarkedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermarked_\(UUID().uuidString).mp4")
        
        let intermediateAsset = AVAsset(url: intermediateURL)
        let watermarkComposition = try await watermarkService.applyWatermark(
            to: intermediateAsset,
            date: Date(),
            title: title
        )
        
        guard let finalExportSession = AVAssetExportSession(
            asset: intermediateAsset,
            presetName: AVAssetExportPreset1280x720
        ) else {
            print("❌ Failed to create final export session")
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        finalExportSession.outputURL = watermarkedURL
        finalExportSession.outputFileType = .mp4
        finalExportSession.shouldOptimizeForNetworkUse = true
        finalExportSession.videoComposition = watermarkComposition
        
        print("🎬 Exporting final file...")
        await finalExportSession.export()
        
        if finalExportSession.status != .completed {
            print("❌ Final export failed with status: \(finalExportSession.status.rawValue)")
            if let error = finalExportSession.error {
                print("❌ Export error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                let nsError = error as NSError
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("❌ Underlying error domain: \(underlying.domain)")
                    print("❌ Underlying error code: \(underlying.code)")
                }
            }
            throw VideoProcessingError.exportFailed
        }
        
        // Clean up intermediate file
        try? FileManager.default.removeItem(at: intermediateURL)
        
        print("🎬 Video processing completed successfully")
        
        // Upload to Firebase Storage
        let storageRef = storage.reference()
        let videoRef = storageRef.child("dreams/\(userId)/\(dreamId).mp4")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await videoRef.putFileAsync(from: watermarkedURL, metadata: metadata)
        let downloadURL = try await videoRef.downloadURL()
        
        print("🎬 Video uploaded successfully")
        print("🎬 Download URL: \(downloadURL)")
        print("🎬 Audio URL: \(audioDownloadURL)")
        
        // Clean up the temporary processed video if it's not the AI video
        if videoURL == nil {
            try? FileManager.default.removeItem(at: processedVideoURL)
        }
        
        // Return both URLs and local path
        return (downloadURL, audioDownloadURL, watermarkedURL.lastPathComponent)
    }
    
    func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    func createVideoWithAIAndAudio(
        replicateVideoURL: URL,
        audioURL: URL,
        userId: String,
        dreamId: String,
        style: DreamVideoStyle,
        title: String? = nil
    ) async throws -> (videoURL: URL, audioURL: URL, localPath: String) {
        isProcessing = true
        progress = 0
        error = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            let result = try await assetService.createVideoWithAIAndAudio(
                replicateVideoURL: replicateVideoURL,
                audioURL: audioURL,
                userId: userId,
                dreamId: dreamId,
                style: style,
                title: title
            )
            progress = 1.0
            return result
        } catch {
            self.error = error
            throw error
        }
    }
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case invalidAsset
    case unknown
    case processingFailed(Error)
    case uploadFailed(Error)
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Failed to export video"
        case .exportCancelled:
            return "Video export was cancelled"
        case .invalidAsset:
            return "Video file is invalid or corrupted"
        case .unknown:
            return "An unknown error occurred"
        case .processingFailed(let error):
            return "Failed to process video: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Failed to upload video: \(error.localizedDescription)"
        case .invalidInput:
            return "Invalid input for video processing"
        }
    }
} 
