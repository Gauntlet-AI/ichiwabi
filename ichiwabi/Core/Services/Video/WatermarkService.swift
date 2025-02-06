import Foundation
import UIKit
import CoreImage
import AVFoundation

@MainActor
final class WatermarkService {
    static let shared = WatermarkService()
    
    private init() {}
    
    func createWatermarkImage(
        date: Date,
        title: String?,
        size: CGSize
    ) -> UIImage? {
        // Create a context to draw in
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext(),
              let watermarkBackground = UIImage(named: "watermark") else { return nil }
        
        // Calculate watermark size (20% of video height)
        let watermarkHeight = size.height * 0.2
        let watermarkWidth = watermarkHeight * (watermarkBackground.size.width / watermarkBackground.size.height)
        let watermarkRect = CGRect(
            x: size.width - watermarkWidth - 20, // 20 pixels from right edge
            y: 20, // 20 pixels from top
            width: watermarkWidth,
            height: watermarkHeight
        )
        
        // Draw watermark background
        watermarkBackground.draw(in: watermarkRect)
        
        // Set up text attributes with dark color
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = dateFormatter.string(from: date)
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: watermarkHeight * 0.25, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        
        // Calculate text position (centered on watermark)
        let text = title ?? dateString
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let textPoint = CGPoint(
            x: watermarkRect.midX - (textSize.width / 2),
            y: watermarkRect.midY - (textSize.height / 2)
        )
        
        // Draw text
        (text as NSString).draw(at: textPoint, withAttributes: textAttributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func applyWatermark(
        to videoAsset: AVAsset,
        date: Date,
        title: String? = nil
    ) async throws -> AVMutableVideoComposition {
        // Get video size
        guard let track = try? await videoAsset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize) else {
            throw WatermarkError.videoTrackNotFound
        }
        
        // Create watermark image
        guard let watermarkImage = createWatermarkImage(
            date: date,
            title: title,
            size: size
        ) else {
            throw WatermarkError.watermarkCreationFailed
        }
        
        // Create CIImage from watermark
        guard let watermarkCIImage = CIImage(image: watermarkImage) else {
            throw WatermarkError.watermarkCreationFailed
        }
        
        // Create video composition
        let composition = AVMutableVideoComposition(asset: videoAsset) { request in
            // Get the source frame
            let source = request.sourceImage
            
            // Composite watermark over video frame
            let output = source.composited(over: watermarkCIImage)
            
            // Return the combined image
            request.finish(with: output, context: nil)
        }
        
        return composition
    }
}

// MARK: - Errors
enum WatermarkError: LocalizedError {
    case videoTrackNotFound
    case watermarkCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .videoTrackNotFound:
            return "Could not find video track in asset"
        case .watermarkCreationFailed:
            return "Failed to create watermark image"
        }
    }
} 