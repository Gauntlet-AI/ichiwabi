import Foundation
import AVFoundation
import CoreMedia
import UIKit
import SwiftUI

@MainActor
final class VideoProcessingService: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published var error: Error?
    
    private let watermarkService = WatermarkService.shared
    
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
        duration: Double,
        date: Date? = nil,
        title: String? = nil
    ) async throws {
        let bitrate = await calculateBitrate(for: asset, quality: quality)
        
        // Apply watermark if date is provided
        if let date = date {
            let composition = try await watermarkService.applyWatermark(
                to: asset,
                date: date,
                title: title
            )
            exportSession.videoComposition = composition
        } else {
            let composition = await createVideoComposition(for: asset)
            exportSession.videoComposition = composition
        }
        
        exportSession.fileLengthLimit = Int64(Double(bitrate) * duration / 8.0)
    }
    
    @MainActor
    private func setupExportSession(
        _ exportSession: AVAssetExportSession,
        outputURL: URL,
        startTime: Double,
        endTime: Double,
        asset: AVAsset,
        quality: VideoQuality,
        date: Date? = nil,
        title: String? = nil
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
            duration: endTime - startTime,
            date: date,
            title: title
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
    
    func trimVideo(at videoURL: URL, from startTime: Double, to endTime: Double, date: Date, title: String?) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        
        // Validate time range
        let validatedStart = max(0, min(startTime, duration))
        let validatedEnd = max(validatedStart + 1, min(endTime, duration))
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        // Create temporary URL for trimmed video
        let trimmedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Configure export session
        exportSession.outputURL = trimmedURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: validatedStart, preferredTimescale: 600),
            end: CMTime(seconds: validatedEnd, preferredTimescale: 600)
        )
        
        // Add watermark
        let videoComposition = try await createWatermarkedComposition(for: asset, date: date)
        exportSession.videoComposition = videoComposition
        
        // Export the video
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
        
        return trimmedURL
    }
    
    private func createWatermarkImage(date: Date, size: CGSize) throws -> UIImage {
        print("🎨 Starting watermark creation with size: \(size)")
        
        // Ensure we're on the main thread for SwiftUI view creation
        if !Thread.isMainThread {
            print("🎨 Not on main thread, switching to main thread")
            var result: UIImage?
            var error: Error?
            
            DispatchQueue.main.sync {
                do {
                    result = try self.createWatermarkImage(date: date, size: size)
                } catch let err {
                    error = err
                }
            }
            
            if let error = error {
                throw error
            }
            return result ?? UIImage()
        }
        
        print("🎨 Creating renderer")
        let renderer = UIGraphicsImageRenderer(size: size)
        
        print("🎨 Creating watermark image")
        let image = renderer.image { context in
            print("🎨 Setting up hosting controller")
            // Create a hosting controller for the watermark view
            let watermarkView = WatermarkView(
                date: date,
                title: nil  // We'll add the title when saving the dream
            )
            let hostingController = UIHostingController(rootView: watermarkView)
            hostingController.view.backgroundColor = .clear
            
            print("🎨 Configuring watermark size and position")
            // Size the hosting view
            let watermarkSize = CGSize(width: size.width * 0.4, height: size.height * 0.15)
            hostingController.view.frame = CGRect(
                x: 20,
                y: size.height - watermarkSize.height - 20,
                width: watermarkSize.width,
                height: watermarkSize.height
            )
            
            print("🎨 Rendering watermark")
            // Render the view
            hostingController.view.drawHierarchy(
                in: hostingController.view.bounds,
                afterScreenUpdates: true
            )
        }
        
        print("🎨 Watermark creation completed")
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
            
            print("🎨 Creating watermark for frame")
            // Create the watermark image
            let watermarkImage = try? self.createWatermarkImage(date: date, size: request.renderSize)
            
            print("🎨 Rendering frame with watermark")
            // Render the original video frame
            let image = request.sourceImage
            
            // If we have a watermark, composite it over the video frame
            if let watermarkImage = watermarkImage,
               let watermark = CIImage(image: watermarkImage)?.transformed(by: CGAffineTransform(
                    translationX: 20,
                    y: 20
               )) {
                print("🎨 Compositing watermark over frame")
                let result = image.composited(over: watermark)
                request.finish(with: result, context: nil)
            } else {
                print("🎨 No watermark available, using original frame")
                request.finish(with: image, context: nil)
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
