import Foundation
import AVFoundation
import UIKit

enum VideoAssetError: LocalizedError {
    case assetNotFound
    case invalidAsset
    case loadFailed(Error)
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "Base video asset not found"
        case .invalidAsset:
            return "Invalid video asset"
        case .loadFailed(let error):
            return "Failed to load video asset: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export video: \(error.localizedDescription)"
        }
    }
}

actor VideoAssetService {
    // MARK: - Properties
    private var baseVideoAssets: [DreamVideoStyle: AVAsset] = [:]
    
    // MARK: - Initialization
    init() {
        // We'll load videos on demand instead of at init
    }
    
    // MARK: - Asset Loading
    private func loadBaseVideo(for style: DreamVideoStyle) -> AVAsset? {
        let assetName: String
        switch style {
        case .realistic:
            assetName = "DreamBaseImageRealistic"
        case .animated:
            assetName = "DreamBaseImageAnimated"
        case .cursed:
            assetName = "DreamBaseImageCursed"
        }
        
        print("\n📼 ==================== LOADING BASE VIDEO ====================")
        print("📼 Attempting to load video for style: \(style)")
        print("📼 Looking for asset named: \(assetName)")
        
        // Debug bundle information
        print("📼 Bundle details:")
        print("📼 - Bundle identifier: \(Bundle.main.bundleIdentifier ?? "none")")
        print("📼 - Bundle path: \(Bundle.main.bundlePath)")
        print("📼 - Resource path: \(Bundle.main.resourcePath ?? "none")")
        
        // First try Resources folder specifically
        print("\n📼 Trying Resources folder first:")
        if let videoURL = Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Resources") {
            print("✅ Found video in Resources folder at: \(videoURL)")
            if FileManager.default.fileExists(atPath: videoURL.path) {
                print("✅ File exists at path")
                return AVAsset(url: videoURL)
            } else {
                print("❌ File does not exist at path despite URL being found")
            }
        }
        
        // If not in Resources, try root bundle
        print("\n📼 Trying root bundle:")
        if let videoURL = Bundle.main.url(forResource: assetName, withExtension: "mp4") {
            print("✅ Found video in root bundle at: \(videoURL)")
            if FileManager.default.fileExists(atPath: videoURL.path) {
                print("✅ File exists at path")
                return AVAsset(url: videoURL)
            } else {
                print("❌ File does not exist at path despite URL being found")
            }
        }
        
        // If still not found, list all bundle contents for debugging
        if let resourcePath = Bundle.main.resourcePath {
            print("\n📼 Listing all files in resource path:")
            let fileManager = FileManager.default
            do {
                let items = try fileManager.contentsOfDirectory(atPath: resourcePath)
                print("📼 Found \(items.count) items:")
                items.forEach { item in
                    print("📼 - \(item)")
                }
                
                // Check Resources folder specifically
                let resourcesPath = (resourcePath as NSString).appendingPathComponent("Resources")
                if fileManager.fileExists(atPath: resourcesPath) {
                    print("\n📼 Contents of Resources folder:")
                    let resourceItems = try fileManager.contentsOfDirectory(atPath: resourcesPath)
                    resourceItems.forEach { item in
                        print("📼 - \(item)")
                    }
                } else {
                    print("\n❌ Resources folder not found at: \(resourcesPath)")
                }
            } catch {
                print("❌ Error listing directory: \(error)")
            }
        }
        
        print("\n❌ Video not found in any location")
        print("❌ Searched for: \(assetName).mp4")
        print("📼 ==================== END LOADING ====================\n")
        return nil
    }
    
    // MARK: - Public Methods
    func getBaseVideoAsset(for style: DreamVideoStyle) throws -> AVAsset {
        // Return cached asset if available
        if let asset = baseVideoAssets[style] {
            return asset
        }
        
        // Load and cache the asset
        if let asset = loadBaseVideo(for: style) {
            baseVideoAssets[style] = asset
            return asset
        }
        
        throw VideoAssetError.assetNotFound
    }
    
    func getVideoDuration(for style: DreamVideoStyle) async throws -> TimeInterval {
        let asset = try getBaseVideoAsset(for: style)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    // MARK: - Video Processing
    func createVideoWithAudio(audioURL: URL, duration: TimeInterval, style: DreamVideoStyle) async throws -> URL {
        print("\n🎬 ==================== CREATING VIDEO WITH AUDIO ====================")
        let baseAsset = try getBaseVideoAsset(for: style)
        let audioAsset = AVAsset(url: audioURL)
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let sourceVideoTrack = try? await baseAsset.loadTracks(withMediaType: .video).first else {
            throw VideoAssetError.invalidAsset
        }
        
        // Add audio track
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let sourceAudioTrack = try? await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw VideoAssetError.invalidAsset
        }
        
        // Get durations
        let videoDuration = try await baseAsset.load(.duration)
        let targetDuration = CMTime(seconds: duration, preferredTimescale: 600)
        
        print("🎬 Base video duration: \(videoDuration.seconds) seconds")
        print("🎬 Target duration: \(duration) seconds")
        
        // Insert audio track for its full duration
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: targetDuration),
            of: sourceAudioTrack,
            at: .zero
        )
        
        // Loop video to fill the audio duration
        var currentTime = CMTime.zero
        let videoDurationTime = videoDuration
        
        print("🎬 Starting video loop insertion")
        
        while currentTime < targetDuration {
            let remainingTime = targetDuration - currentTime
            if remainingTime < videoDurationTime {
                // For the last loop, we might need to trim the video
                let finalRange = CMTimeRange(
                    start: .zero,
                    duration: remainingTime
                )
                try compositionVideoTrack.insertTimeRange(finalRange, of: sourceVideoTrack, at: currentTime)
                break
            }
            
            // Insert full video segment
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDurationTime),
                of: sourceVideoTrack,
                at: currentTime
            )
            currentTime = CMTimeAdd(currentTime, videoDurationTime)
            print("🎬 Inserted video loop at time: \(currentTime.seconds) seconds")
        }
        
        print("🎬 Video looping complete")
        print("🎬 Final composition duration: \(try await composition.load(.duration).seconds) seconds")
        
        // Create export session
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoAssetError.invalidAsset
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Export
        print("🎬 Starting export...")
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            print("❌ Export failed with error: \(String(describing: exportSession.error))")
            if let error = exportSession.error {
                print("❌ Error details: \(error.localizedDescription)")
                if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                    print("❌ Underlying error: \(underlyingError)")
                }
            }
            throw VideoAssetError.exportFailed(exportSession.error ?? NSError(domain: "VideoAsset", code: -1))
        }
        
        print("✅ Export completed successfully")
        print("🎬 ==================== END CREATING VIDEO WITH AUDIO ====================\n")
        return tempURL
    }
    
    private func orientation(from transform: CGAffineTransform, naturalSize: CGSize) -> (transform: CGAffineTransform, size: CGSize, isPortrait: Bool) {
        let angle = atan2(transform.b, transform.a)
        let isPortrait = abs(angle) > .pi / 4 && abs(angle) < .pi * 3 / 4
        
        var finalTransform = CGAffineTransform.identity
        var size = naturalSize
        
        if isPortrait {
            // Rotate to portrait
            finalTransform = CGAffineTransform(rotationAngle: .pi / 2)
            size = CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        
        return (finalTransform, size, isPortrait)
    }
    
    private func createReversedVideoTrack(from track: AVAssetTrack, duration: CMTime) async throws -> AVAssetTrack {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoAssetError.invalidAsset
        }
        
        // Create reversed transform
        var transform = try await track.load(.preferredTransform)
        transform.a *= -1 // Reverse horizontal direction
        
        // Insert time range with reversed transform
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: track,
            at: .zero
        )
        compositionTrack.preferredTransform = transform
        
        return compositionTrack
    }
} 