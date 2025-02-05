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
    
    func trimVideo(
        at url: URL,
        from startTime: Double,
        to endTime: Double,
        quality: VideoQuality = .medium
    ) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let asset = AVAsset(url: url)
        
        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Create export session with quality preset
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
        
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Create and configure video composition on the main actor
        let composition = AVMutableVideoComposition(asset: asset) { _ in }
        
        // Set video composition if valid
        if composition.renderSize.width > 0 && composition.renderSize.height > 0 {
            exportSession.videoComposition = composition
        }
        
        // Perform the export
        await exportSession.export()
        
        // Handle result
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? VideoProcessingError.exportFailed
        case .cancelled:
            throw VideoProcessingError.exportCancelled
        default:
            throw VideoProcessingError.unknown
        }
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