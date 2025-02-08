import Foundation
import UIKit
@preconcurrency import CoreImage
import AVFoundation

// Cache struct to fix large tuple warning
private struct WatermarkCache {
    let image: UIImage
    let size: CGSize
    let date: Date
    let title: String?
}

@MainActor
final class WatermarkService {
    static let shared = WatermarkService()
    private var cachedWatermark: WatermarkCache?
    
    private init() {}
    
    private func createWatermarkImage(
        date: Date,
        title: String?,
        size: CGSize
    ) -> UIImage? {
        print("🎨 Starting watermark creation")
        print("🎨 Creating image with size: \(size)")
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Calculate watermark dimensions
        let padding: CGFloat = 20 // Was 24
        let innerPadding: CGFloat = 14 // Was 16
        let watermarkHeight: CGFloat = title != nil ? 340 : 255 // Was 400/300
        let watermarkWidth: CGFloat = min(size.width - (padding * 2), 680) // Was 800
        
        // Position at bottom right with padding
        let watermarkRect = CGRect(
            x: size.width - watermarkWidth - padding,
            y: size.height - watermarkHeight - padding,
            width: watermarkWidth,
            height: watermarkHeight
        )
        
        // Draw rounded rectangle background
        let path = UIBezierPath(roundedRect: watermarkRect, cornerRadius: 20) // Was 24
        UIColor.black.withAlphaComponent(0.5).setFill()
        path.fill()
        
        // Current Y position for text layout
        var currentY = watermarkRect.minY + innerPadding * 2
        
        // App branding
        let appTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 68, weight: .bold), // Was 80
            .foregroundColor: UIColor.white
        ]
        
        let appTitle = "ｙｏｒｕｔａｂｉ"
        let appTitleSize = (appTitle as NSString).size(withAttributes: appTitleAttributes)
        
        // Draw moon icon
        let moonSymbolConfig = UIImage.SymbolConfiguration(pointSize: 68, weight: .bold) // Was 80
        if let moonImage = UIImage(systemName: "moon.stars.fill", withConfiguration: moonSymbolConfig) {
            let moonRect = CGRect(
                x: watermarkRect.maxX - appTitleSize.width - moonImage.size.width - innerPadding - 17, // Was 20
                y: currentY,
                width: moonImage.size.width,
                height: moonImage.size.height
            )
            moonImage.withTintColor(.white).draw(in: moonRect)
        }
        
        // Draw app title
        let appTitlePoint = CGPoint(
            x: watermarkRect.maxX - appTitleSize.width - innerPadding,
            y: currentY
        )
        (appTitle as NSString).draw(at: appTitlePoint, withAttributes: appTitleAttributes)
        
        currentY += appTitleSize.height + 17 // Was 20
        
        // Draw dream title if available
        if let title = title {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60, weight: .medium), // Was 70
                .foregroundColor: UIColor.white
            ]
            let titleSize = (title as NSString).size(withAttributes: titleAttributes)
            let titlePoint = CGPoint(
                x: watermarkRect.maxX - titleSize.width - innerPadding,
                y: currentY
            )
            (title as NSString).draw(at: titlePoint, withAttributes: titleAttributes)
            currentY += titleSize.height + 17 // Was 20
        }
        
        // Draw date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 51), // Was 60
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let dateString = date.formatted(date: .abbreviated, time: .omitted)
        let dateSize = (dateString as NSString).size(withAttributes: dateAttributes)
        let datePoint = CGPoint(
            x: watermarkRect.maxX - dateSize.width - innerPadding,
            y: currentY
        )
        (dateString as NSString).draw(at: datePoint, withAttributes: dateAttributes)
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            print("❌ Failed to create watermark image")
            return nil
        }
        
        print("✅ Watermark image created successfully")
        print("🎨 - Final image size: \(image.size)")
        return image
    }
    
    func applyWatermark(
        to videoAsset: AVAsset,
        date: Date,
        title: String? = nil
    ) async throws -> AVMutableVideoComposition {
        print("\n🎬 Starting watermark application")
        
        // Wait for tracks to load
        let tracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            print("❌ No video tracks found in asset")
            throw WatermarkError.videoTrackNotFound
        }
        
        let track = tracks[0]
        print("✅ Found video track")
        
        // Load track properties
        let size = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        
        // Apply preferred transform to get correct orientation
        let transformedSize = size.applying(preferredTransform)
        let finalSize = CGSize(
            width: abs(transformedSize.width),
            height: abs(transformedSize.height)
        )
        
        print("🎬 Video details:")
        print("🎬 - Original size: \(size)")
        print("🎬 - Transformed size: \(finalSize)")
        
        // Create watermark image using the final size
        guard let watermarkImage = createWatermarkImage(date: date, title: title, size: finalSize) else {
            print("❌ Failed to create watermark image")
            throw WatermarkError.watermarkCreationFailed
        }
        
        print("🎬 Converting watermark to CIImage")
        guard var watermarkCIImage = CIImage(image: watermarkImage) else {
            print("❌ Failed to convert watermark to CIImage")
            throw WatermarkError.watermarkCreationFailed
        }
        
        // Scale the watermark CIImage to match video dimensions
        let scale = CGAffineTransform(scaleX: 1.0/3.0, y: 1.0/3.0)
        watermarkCIImage = watermarkCIImage.transformed(by: scale)
        
        print("✅ Converted to CIImage")
        print("🎬 - Original CIImage extent: \(watermarkCIImage.extent)")
        
        // Ensure the watermark is properly bounded
        let boundedWatermark = watermarkCIImage.clampedToExtent()
        print("🎬 - Clamped CIImage extent: \(boundedWatermark.extent)")
        
        var frameCount = 0
        
        // Create video composition
        print("🎬 Creating video composition")
        let composition = AVMutableVideoComposition(asset: videoAsset) { request in
            frameCount += 1
            if frameCount == 1 {
                print("🎬 Processing first frame:")
            }
            
            // Get source image and ensure it's properly bounded
            let sourceImage = request.sourceImage.clampedToExtent()
            
            // Create a new compositing filter for each frame
            guard let compositingFilter = CIFilter(name: "CISourceOverCompositing") else {
                print("❌ Failed to create filter for frame \(frameCount)")
                request.finish(with: sourceImage, context: nil)
                return
            }
            
            // Apply watermark
            compositingFilter.setValue(boundedWatermark, forKey: kCIInputImageKey)
            compositingFilter.setValue(sourceImage, forKey: kCIInputBackgroundImageKey)
            
            if let output = compositingFilter.outputImage?.cropped(to: sourceImage.extent) {
                if frameCount == 1 {
                    print("✅ First frame composited successfully")
                    print("🎬 - Output image extent: \(output.extent)")
                }
                request.finish(with: output, context: nil)
            } else {
                print("❌ Failed to get output image for frame \(frameCount)")
                request.finish(with: sourceImage, context: nil)
            }
        }
        
        // Set high quality rendering
        composition.renderSize = finalSize
        composition.renderScale = 1.0 // Full resolution
        composition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
        
        print("🎬 Composition created with render size: \(finalSize)")
        
        return composition
    }
}

// MARK: - Errors
enum WatermarkError: LocalizedError {
    case videoTrackNotFound
    case watermarkCreationFailed
    case filterCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .videoTrackNotFound:
            return "Could not find video track in asset"
        case .watermarkCreationFailed:
            return "Failed to create watermark image"
        case .filterCreationFailed:
            return "Failed to create compositing filter"
        }
    }
}