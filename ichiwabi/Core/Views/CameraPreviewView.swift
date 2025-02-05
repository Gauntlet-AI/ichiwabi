import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let videoCaptureService: VideoCaptureService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        videoCaptureService.startPreview(in: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update view if needed
    }
} 