import Foundation
import AVFoundation
import UIKit
import FirebaseStorage

enum VideoAssetError: LocalizedError {
    case assetNotFound
    case invalidAsset
    case loadFailed(Error)
    case exportFailed(Error)
    case downloadFailed
    
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
        case .downloadFailed:
            return "Failed to download video"
        }
    }
}

actor VideoAssetService {
    // MARK: - Properties
    private var baseVideoAssets: [DreamVideoStyle: AVAsset] = [:]
    
    @MainActor
    private static let sharedWatermarkService = WatermarkService.shared
    
    // MARK: - Initialization
    init() {
        // We'll load videos on demand instead of at init
    }
    
    // Helper to access watermark service safely
    @MainActor
    private func getWatermarkService() -> WatermarkService {
        return Self.sharedWatermarkService
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
        
        print("\n🔍 ==================== LOADING BASE VIDEO ====================")
        print("🔍 Attempting to load video for style: \(style)")
        print("🔍 Looking for asset named: \(assetName)")
        
        // Debug bundle information
        print("🔍 Bundle details:")
        print("🔍 - Bundle identifier: \(Bundle.main.bundleIdentifier ?? "none")")
        print("🔍 - Bundle path: \(Bundle.main.bundlePath)")
        print("🔍 - Resource path: \(String(describing: Bundle.main.resourcePath ?? "none"))")
        
        // First try Resources folder specifically
        print("\n🔍 Trying Resources folder first...")
        if let resourcePath = Bundle.main.resourcePath {
            let resourcesPath = (resourcePath as NSString).appendingPathComponent("Resources")
            print("🔍 Full Resources path: \(resourcesPath)")
            print("🔍 Resources folder exists: \(FileManager.default.fileExists(atPath: resourcesPath))")
            
            let expectedVideoPath = (resourcesPath as NSString).appendingPathComponent("\(assetName).mp4")
            print("🔍 Expected video path: \(expectedVideoPath)")
            print("🔍 Video file exists: \(FileManager.default.fileExists(atPath: expectedVideoPath))")
        }
        
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
        print("\n🔍 Trying root bundle...")
        if let resourcePath = Bundle.main.resourcePath {
            let expectedVideoPath = (resourcePath as NSString).appendingPathComponent("\(assetName).mp4")
            print("🔍 Expected video path: \(expectedVideoPath)")
            print("🔍 Video file exists: \(FileManager.default.fileExists(atPath: expectedVideoPath))")
        }
        
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
            print("\n🔍 Listing all files in resource path:")
            let fileManager = FileManager.default
            do {
                let items = try fileManager.contentsOfDirectory(atPath: resourcePath)
                print("🔍 Found \(items.count) items:")
                items.forEach { item in
                    print("🔍 - \(item)")
                }
                
                // Check Resources folder specifically
                let resourcesPath = (resourcePath as NSString).appendingPathComponent("Resources")
                if fileManager.fileExists(atPath: resourcesPath) {
                    print("\n🔍 Contents of Resources folder:")
                    let resourceItems = try fileManager.contentsOfDirectory(atPath: resourcesPath)
                    print("🔍 Found \(resourceItems.count) items:")
                    resourceItems.forEach { item in
                        print("🔍 - \(item)")
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
        print("🔍 ==================== END LOADING ====================\n")
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
        return try await Task.detached { [self] () -> URL in
            print("\n⭐️ STEP 1: Starting video creation")
            print("⭐️ Audio URL: \(audioURL)")
            print("⭐️ Duration: \(duration)")
            print("⭐️ Style: \(style)")
            
            // Configure audio session first
            print("\n⭐️ STEP 2: Configuring audio session")
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("⭐️ Audio session configured")
            
            // Get base video
            print("\n⭐️ STEP 3: Loading base video asset")
            let baseAsset = try await getBaseVideoAsset(for: style)
            print("⭐️ Base asset loaded successfully")
            
            // Create video-only composition first
            print("\n⭐️ STEP 4: Creating video composition")
            let composition = AVMutableComposition()
            
            // Create video track
            guard let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create video track")
                throw VideoAssetError.invalidAsset
            }
            
            // Load video track
            guard let baseVideoTrack = try await baseAsset.loadTracks(withMediaType: .video).first else {
                print("❌ No video track found in base asset")
                throw VideoAssetError.invalidAsset
            }
            
            // Calculate time ranges
            print("\n⭐️ STEP 5: Calculating durations")
            let videoDuration = try await baseAsset.load(.duration)
            let targetDuration = CMTime(seconds: duration, preferredTimescale: 600)
            print("⭐️ Video duration: \(videoDuration.seconds)s")
            print("⭐️ Target duration: \(targetDuration.seconds)s")
            
            // Loop video to match target duration
            print("\n⭐️ STEP 6: Creating looped video")
            var currentTime = CMTime.zero
            while currentTime < targetDuration {
                let remainingTime = targetDuration - currentTime
                let insertDuration = min(remainingTime, videoDuration)
                
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: baseVideoTrack,
                    at: currentTime
                )
                
                currentTime = CMTimeAdd(currentTime, insertDuration)
            }
            
            // Export video-only composition first
            print("\n⭐️ STEP 7: Exporting video-only composition")
            let videoOnlyURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_video.mp4")
            
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPreset1280x720
            ) else {
                print("❌ Failed to create export session")
                throw VideoAssetError.invalidAsset
            }
            
            exportSession.outputURL = videoOnlyURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            print("⭐️ Starting video-only export")
            await exportSession.export()
            guard exportSession.status == .completed else {
                if let error = exportSession.error {
                    print("❌ Export failed with error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("❌ Underlying error: \(underlyingError)")
                    }
                }
                throw VideoAssetError.exportFailed(exportSession.error ?? NSError(domain: "VideoAsset", code: -1))
            }
            
            // Now create a new composition with both video and audio
            print("\n⭐️ STEP 8: Creating final composition with audio")
            let finalComposition = AVMutableComposition()
            
            // Add video track
            guard let finalVideoTrack = finalComposition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create final video track")
                throw VideoAssetError.invalidAsset
            }
            
            // Add audio track
            guard let finalAudioTrack = finalComposition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create final audio track")
                throw VideoAssetError.invalidAsset
            }
            
            // Load the exported video
            let exportedVideoAsset = AVAsset(url: videoOnlyURL)
            let audioAsset = AVAsset(url: audioURL)
            
            // Get source tracks
            guard let sourceVideoTrack = try await exportedVideoAsset.loadTracks(withMediaType: .video).first,
                  let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
                print("❌ Failed to load source tracks")
                throw VideoAssetError.invalidAsset
            }
            
            // Insert tracks
            print("⭐️ Inserting final video and audio tracks")
            try finalVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: targetDuration),
                of: sourceVideoTrack,
                at: .zero
            )
            
            try finalAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: targetDuration),
                of: sourceAudioTrack,
                at: .zero
            )
            
            // Export final composition
            print("\n⭐️ STEP 9: Exporting final composition")
            let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_final.mp4")
            
            guard let finalExportSession = AVAssetExportSession(
                asset: finalComposition,
                presetName: AVAssetExportPreset1280x720
            ) else {
                print("❌ Failed to create final export session")
                throw VideoAssetError.invalidAsset
            }
            
            finalExportSession.outputURL = finalURL
            finalExportSession.outputFileType = .mp4
            finalExportSession.shouldOptimizeForNetworkUse = true
            
            // Use less demanding audio settings
            if #available(iOS 15.0, *) {
                finalExportSession.audioTimePitchAlgorithm = .timeDomain
            } else {
                finalExportSession.audioTimePitchAlgorithm = .lowQualityZeroLatency
            }
            finalExportSession.audioMix = nil
            
            print("⭐️ Starting final export")
            await finalExportSession.export()
            guard finalExportSession.status == .completed else {
                if let error = finalExportSession.error {
                    print("❌ Export failed with error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("❌ Underlying error: \(underlyingError)")
                    }
                }
                throw VideoAssetError.exportFailed(finalExportSession.error ?? NSError(domain: "VideoAsset", code: -1))
            }
            
            // Clean up intermediate file
            try? FileManager.default.removeItem(at: videoOnlyURL)
            
            return finalURL
        }.value
    }
    
    // MARK: - AI Video Processing
    func createVideoWithAIAndAudio(
        replicateVideoURL: URL,
        audioURL: URL,
        userId: String,
        dreamId: String,
        style: DreamVideoStyle,
        title: String? = nil
    ) async throws -> (videoURL: URL, audioURL: URL, localPath: String) {
        print("\n🎬 ==================== CREATING AI VIDEO WITH AUDIO ====================")
        print("🎬 Replicate URL: \(replicateVideoURL)")
        print("🎬 Audio URL: \(audioURL)")
        print("🎬 Title: \(title ?? "none")")
        
        // Debug audio session state
        print("\n🔊 ==================== AUDIO SESSION DEBUG ====================")
        let audioSession = AVAudioSession.sharedInstance()
        print("🔊 Current audio session state:")
        print("🔊 - Category: \(audioSession.category.rawValue)")
        print("🔊 - Mode: \(audioSession.mode.rawValue)")
        print("🔊 - Sample rate: \(audioSession.sampleRate)")
        print("🔊 - Preferred IO buffer duration: \(audioSession.preferredIOBufferDuration)")
        print("🔊 - Input available: \(audioSession.isInputAvailable)")
        print("🔊 - Other audio playing: \(audioSession.isOtherAudioPlaying)")
        
        // Configure audio session
        do {
            print("🔊 Configuring audio session...")
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("🔊 Audio session configured successfully")
            print("🔊 - New category: \(audioSession.category.rawValue)")
            print("🔊 - New mode: \(audioSession.mode.rawValue)")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            if let avError = error as? AVError {
                print("❌ AVError code: \(avError.code.rawValue)")
            }
        }
        
        // Debug audio file
        print("\n🔊 Analyzing audio file...")
        let audioAsset = AVAsset(url: audioURL)
        let audioExists = FileManager.default.fileExists(atPath: audioURL.path)
        print("🔊 Audio file exists: \(audioExists)")
        if audioExists {
            let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
            print("🔊 Audio file size: \(attributes?[.size] ?? 0) bytes")
        }
        
        // Load and check audio tracks
        if let audioTracks = try? await audioAsset.loadTracks(withMediaType: .audio) {
            print("🔊 Audio tracks found: \(audioTracks.count)")
            for (index, track) in audioTracks.enumerated() {
                print("🔊 Track \(index):")
                print("🔊 - Format descriptions: \(String(describing: try? await track.load(.formatDescriptions)))")
                if let formatDescriptions = try? await track.load(.formatDescriptions) as [CMFormatDescription],
                   let firstFormat = formatDescriptions.first,
                   let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(firstFormat) {
                    print("🔊 - Sample rate: \(basicDescription.pointee.mSampleRate)")
                    print("🔊 - Channels: \(basicDescription.pointee.mChannelsPerFrame)")
                    print("🔊 - Bytes per frame: \(basicDescription.pointee.mBytesPerFrame)")
                    print("🔊 - Format ID: \(basicDescription.pointee.mFormatID)")
                }
            }
        } else {
            print("❌ Failed to load audio tracks")
        }
        print("🔊 ==================== END AUDIO DEBUG ====================\n")
        
        // First, upload the audio file to Firebase Storage
        let audioRef = Storage.storage().reference().child("users/\(userId)/audio/\(dreamId).m4a")
        let audioMetadata = StorageMetadata()
        audioMetadata.contentType = "audio/m4a"
        
        print("🎬 Uploading audio file to Firebase Storage")
        _ = try await audioRef.putFileAsync(from: audioURL, metadata: audioMetadata)
        let audioDownloadURL = try await audioRef.downloadURL()
        print("🎬 Audio file uploaded successfully: \(audioDownloadURL)")
        
        // Get audio duration
        let audioDuration = try await audioAsset.load(.duration).seconds
        print("🎬 Audio duration: \(audioDuration) seconds")
        
        // Download the Replicate video
        let (tempURL, response) = try await URLSession.shared.download(from: replicateVideoURL)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VideoAssetError.downloadFailed
        }
        
        // Move to a temporary file
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let downloadedVideoURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try? FileManager.default.removeItem(at: downloadedVideoURL)
        try FileManager.default.moveItem(at: tempURL, to: downloadedVideoURL)
        print("🎬 Replicate video downloaded to: \(downloadedVideoURL)")
        
        // STEP 1: First create a looped video without audio
        print("🎬 STEP 1: Creating looped video composition")
        let loopedVideoURL = try await createLoopedVideo(
            from: downloadedVideoURL,
            targetDuration: audioDuration
        )
        print("🎬 Looped video created successfully")
        
        // STEP 2: Add audio to the looped video
        print("🎬 STEP 2: Adding audio to looped video")
        let videoWithAudioURL = try await addAudioToVideo(
            videoURL: loopedVideoURL,
            audioURL: audioURL,
            targetDuration: audioDuration,
            title: title
        )
        print("🎬 Audio added successfully")
        
        // Clean up intermediate file
        try? FileManager.default.removeItem(at: loopedVideoURL)
        
        // Upload to Firebase Storage
        print("🎬 Uploading final video to Firebase")
        let videoRef = Storage.storage().reference().child("dreams/\(userId)/\(dreamId).mp4")
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await videoRef.putFileAsync(from: videoWithAudioURL, metadata: metadata)
        let downloadURL = try await videoRef.downloadURL()
        
        print("🎬 Video uploaded successfully")
        print("🎬 Download URL: \(downloadURL)")
        print("🎬 Audio URL: \(audioDownloadURL)")
        print("🎬 ==================== END CREATING AI VIDEO WITH AUDIO ====================\n")
        
        // Clean up temporary files
        try? FileManager.default.removeItem(at: downloadedVideoURL)
        
        return (downloadURL, audioDownloadURL, videoWithAudioURL.lastPathComponent)
    }
    
    // Helper function to create looped video without audio
    private func createLoopedVideo(from videoURL: URL, targetDuration: Double) async throws -> URL {
        return try await Task.detached { () -> URL in
            let asset = AVAsset(url: videoURL)
            let composition = AVMutableComposition()
            
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw VideoAssetError.invalidAsset
            }
            
            let videoDuration = try await asset.load(.duration)
            var currentTime = CMTime.zero
            let targetTime = CMTime(seconds: targetDuration, preferredTimescale: 600)
            
            while currentTime < targetTime {
                let remainingTime = targetTime - currentTime
                let insertDuration = min(remainingTime, videoDuration)
                
                try compositionVideoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: sourceVideoTrack,
                    at: currentTime
                )
                
                currentTime = CMTimeAdd(currentTime, insertDuration)
            }
            
            // Export looped video
            let loopedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("looped_\(UUID().uuidString).mp4")
            
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw VideoAssetError.invalidAsset
            }
            
            exportSession.outputURL = loopedURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            await exportSession.export()
            guard exportSession.status == .completed else {
                if let error = exportSession.error {
                    print("❌ Export failed with error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("❌ Underlying error: \(underlyingError)")
                    }
                }
                throw VideoAssetError.exportFailed(exportSession.error ?? NSError(domain: "VideoAsset", code: -1))
            }
            
            return loopedURL
        }.value
    }
    
    // Helper function to add audio to video
    private func addAudioToVideo(videoURL: URL, audioURL: URL, targetDuration: Double, title: String?) async throws -> URL {
        // Create everything in a single detached task to avoid crossing actor boundaries with non-Sendable types
        return try await Task.detached { () -> URL in
            let videoAsset = AVAsset(url: videoURL)
            let audioAsset = AVAsset(url: audioURL)
            
            // Create composition
            let composition = AVMutableComposition()
            
            // Add video track
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
                throw VideoAssetError.invalidAsset
            }
            
            // Add audio track
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
                throw VideoAssetError.invalidAsset
            }
            
            // Insert video and audio
            let timeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: targetDuration, preferredTimescale: 600)
            )
            
            try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
            
            // Create watermark composition
            let watermarkComposition: AVMutableVideoComposition = try await Task { @MainActor in
                let watermarkService = Self.sharedWatermarkService
                return try await watermarkService.applyWatermark(
                    to: composition,
                    date: Date(),
                    title: title
                )
            }.value
            
            // Export final video
            let finalURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("final_\(UUID().uuidString).mp4")
            
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPreset1280x720
            ) else {
                throw VideoAssetError.invalidAsset
            }
            
            exportSession.outputURL = finalURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.videoComposition = watermarkComposition
            
            if #available(iOS 15.0, *) {
                exportSession.audioTimePitchAlgorithm = .timeDomain
            } else {
                exportSession.audioTimePitchAlgorithm = .lowQualityZeroLatency
            }
            exportSession.audioMix = nil
            
            await exportSession.export()
            guard exportSession.status == .completed else {
                throw VideoAssetError.exportFailed(exportSession.error ?? NSError(domain: "VideoAsset", code: -1))
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: videoURL)
            
            return finalURL
        }.value
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
