import Foundation
import AVFoundation
import CoreMedia

@MainActor
final class VideoProcessingService: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published var error: Error?
    
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
    
    @MainActor
    private func createExportSession(
        asset: AVAsset,
        quality: VideoQuality
    ) throws -> AVAssetExportSession {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        return exportSession
    }
    
    @MainActor
    private func configureBasicSettings(
        _ exportSession: AVAssetExportSession,
        outputURL: URL,
        startTime: Double,
        endTime: Double
    ) {
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
        exportSession.shouldOptimizeForNetworkUse = true
    }
    
    @MainActor
    private func configureVideoSettings(
        _ exportSession: AVAssetExportSession,
        asset: AVAsset,
        quality: VideoQuality,
        duration: Double
    ) async throws {
        let bitrate = await calculateBitrate(for: asset, quality: quality)
        let composition = await createVideoComposition(for: asset)
        exportSession.videoComposition = composition
        exportSession.fileLengthLimit = Int64(Double(bitrate) * duration / 8.0)
    }
    
    @MainActor
    private func setupExportSession(
        _ exportSession: AVAssetExportSession,
        outputURL: URL,
        startTime: Double,
        endTime: Double,
        asset: AVAsset,
        quality: VideoQuality
    ) async throws {
        configureBasicSettings(
            exportSession,
            outputURL: outputURL,
            startTime: startTime,
            endTime: endTime
        )
        
        try await configureVideoSettings(
            exportSession,
            asset: asset,
            quality: quality,
            duration: endTime - startTime
        )
    }
    
    @MainActor
    private func performExport(
        _ exportSession: AVAssetExportSession,
        outputURL: URL
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                exportSession.exportAsynchronously { [exportSession] in
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        print("Export failed with error: \(String(describing: exportSession.error))")
                        continuation.resume(throwing: exportSession.error ?? VideoProcessingError.exportFailed)
                    case .cancelled:
                        continuation.resume(throwing: VideoProcessingError.exportCancelled)
                    default:
                        continuation.resume(throwing: VideoProcessingError.unknown)
                    }
                }
            }
        }
    }
    
    func trimVideo(
        at url: URL,
        from startTime: Double,
        to endTime: Double,
        quality: VideoQuality = .medium
    ) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let asset = AVAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        let session = try createExportSession(asset: asset, quality: quality)
        try await setupExportSession(
            session,
            outputURL: outputURL,
            startTime: startTime,
            endTime: endTime,
            asset: asset,
            quality: quality
        )
        
        return try await performExport(session, outputURL: outputURL)
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
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Failed to export video"
        case .exportCancelled:
            return "Video export was cancelled"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 
