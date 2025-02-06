import SwiftUI
import UIKit
import AVFoundation

class CameraPreviewViewController: UIViewController {
    let videoCaptureService: VideoCaptureService
    private var hasSetupPreview = false
    private var loadingView: UIView?
    private var isSettingUpPreview = false
    private var setupRetryCount = 0
    private var setupTimer: Timer?
    
    init(videoCaptureService: VideoCaptureService) {
        self.videoCaptureService = videoCaptureService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLoadingView()
        
        // Start a timer to retry setup if needed
        setupTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.attemptSetup()
        }
    }
    
    private func attemptSetup() {
        guard !hasSetupPreview && !isSettingUpPreview && view.bounds.width > 0 && view.bounds.height > 0 else {
            return
        }
        
        setupRetryCount += 1
        print("📷 Attempt \(setupRetryCount) to setup preview")
        
        if setupRetryCount >= 50 { // 5 seconds max
            setupTimer?.invalidate()
            setupTimer = nil
            return
        }
        
        isSettingUpPreview = true
        videoCaptureService.startPreview(in: view)
        
        // Check if preview is visible
        if let previewLayer = videoCaptureService.previewLayer,
           previewLayer.superlayer != nil {
            print("📷 Preview layer successfully added")
            hasSetupPreview = true
            setupTimer?.invalidate()
            setupTimer = nil
            
            // Hide loading view with animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                UIView.animate(withDuration: 0.3) {
                    self?.loadingView?.alpha = 0
                } completion: { _ in
                    self?.loadingView?.removeFromSuperview()
                    self?.loadingView = nil
                    self?.isSettingUpPreview = false
                }
            }
        } else {
            isSettingUpPreview = false
        }
    }
    
    private func setupLoadingView() {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        
        let label = UILabel()
        label.text = "Preparing camera..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)
        
        container.addSubview(stack)
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        self.loadingView = container
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let previewLayer = videoCaptureService.previewLayer {
            previewLayer.frame = view.bounds
            view.layer.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setupTimer?.invalidate()
        setupTimer = nil
        hasSetupPreview = false
    }
    
    deinit {
        setupTimer?.invalidate()
        setupTimer = nil
    }
}

struct CameraPreviewView: UIViewControllerRepresentable {
    let videoCaptureService: VideoCaptureService
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        print("📷 Creating CameraPreviewViewController")
        return CameraPreviewViewController(videoCaptureService: videoCaptureService)
    }
    
    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {
        // Only log if something actually needs updating
    }
} 
