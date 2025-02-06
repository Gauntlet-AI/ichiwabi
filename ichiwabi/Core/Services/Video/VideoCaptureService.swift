@preconcurrency import Foundation
@preconcurrency import AVFoundation
import UIKit
import SwiftUI

@MainActor
final class VideoCaptureService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isAuthorized = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentCamera: AVCaptureDevice.Position = .front
    @Published var errorMessage: String?
    
    // MARK: - Constants
    static let maxDuration: TimeInterval = 180 // 3 minutes
    
    // MARK: - Private Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var completion: ((Result<URL, Error>) -> Void)?
    private var setupCompletion: (() -> Void)?
    private var previewView: UIView?
    
    private let sessionQueue = DispatchQueue(label: "com.ichiwabi.camera.session")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        Task {
            await checkAuthorization()
        }
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() async {
        print("📷 Requesting camera authorization")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            print("📷 Authorization status: not determined")
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            print("📷 User authorization response: \(isAuthorized)")
        case .authorized:
            print("📷 Authorization status: authorized")
            isAuthorized = true
        default:
            print("📷 Authorization status: \(status.rawValue)")
            isAuthorized = false
        }
        
        if isAuthorized {
            print("📷 Authorization granted, setting up capture session")
            await setupCaptureSession()
        } else {
            print("📷 Authorization denied")
        }
    }
    
    func startPreview(in view: UIView) {
        print("📷 Attempting to start preview")
        previewView = view
        
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("📷 View bounds are zero, waiting for layout")
            return
        }
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📷 Starting preview setup")
            
            // Remove any existing preview layers
            view.layer.sublayers?.forEach { layer in
                if layer is AVCaptureVideoPreviewLayer {
                    print("📷 Removing existing preview layer")
                    layer.removeFromSuperlayer()
                }
            }
            
            // Create new preview layer if needed
            if self.previewLayer == nil, let session = self.captureSession {
                print("📷 Creating new preview layer")
                let newLayer = AVCaptureVideoPreviewLayer(session: session)
                newLayer.videoGravity = .resizeAspectFill
                
                // Force OpenGL rendering
                if let connection = newLayer.connection {
                    connection.preferredVideoStabilizationMode = .off
                    if #available(iOS 17.0, *) {
                        connection.videoRotationAngle = 90
                    } else {
                        connection.videoOrientation = .portrait
                    }
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (self.currentCamera == .front)
                }
                
                self.previewLayer = newLayer
            }
            
            if let previewLayer = self.previewLayer {
                // Configure preview layer
                print("📷 Configuring preview layer frame: \(view.bounds)")
                previewLayer.frame = view.bounds
                previewLayer.connection?.isEnabled = true
                
                // Force layer to be renderable
                previewLayer.drawsAsynchronously = false  // Disable async drawing
                view.layer.isOpaque = true
                view.backgroundColor = .black
                
                // Add preview layer
                view.layer.insertSublayer(previewLayer, at: 0)
                print("📷 Added preview layer to view")
                
                // Force immediate layout
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                view.setNeedsLayout()
                view.layoutIfNeeded()
                CATransaction.commit()
                
                // Start the session if needed
                if let session = self.captureSession {
                    if !session.isRunning {
                        print("📷 Starting capture session")
                        self.sessionQueue.async {
                            session.startRunning()
                            print("📷 Capture session started")
                            
                            // Force a preview layer update on the main thread
                            DispatchQueue.main.async {
                                previewLayer.setNeedsDisplay()
                            }
                        }
                    } else {
                        print("📷 Session already running")
                        // Force a preview layer update
                        previewLayer.setNeedsDisplay()
                    }
                } else {
                    print("📷 No capture session available")
                }
            } else {
                print("📷 No preview layer available, waiting for setup")
                self.setupCompletion = { [weak self] in
                    guard let self = self else { return }
                    print("📷 Setup completed, starting preview")
                    if let view = self.previewView {
                        self.startPreview(in: view)
                    }
                }
            }
        }
    }
    
    func switchCamera() {
        guard !isRecording else { return }
        print("📷 Switching camera")
        
        // Store current view
        let currentView = previewView
        
        // Stop current session
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        
        currentCamera = currentCamera == .front ? .back : .front
        
        Task {
            await setupCaptureSession()
            if let view = currentView {
                startPreview(in: view)
            }
        }
    }
    
    func startRecording() async throws {
        guard let videoOutput = videoOutput else {
            throw VideoCaptureError.notReady
        }
        
        // Create temporary URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(UUID().uuidString).mov"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        // Start recording
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        recordingURL = tempURL
        isRecording = true
        recordingStartTime = Date()
        
        // Start timer to track duration
        let maxDuration = Self.maxDuration // Capture the constant
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let startTime = self.recordingStartTime else { return }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordingDuration = duration
                
                // Stop recording if max duration reached
                if duration >= maxDuration {
                    do {
                        print("📷 Max duration reached, stopping recording")
                        _ = try await self.stopRecording()
                    } catch {
                        print("📷 Failed to stop recording at max duration: \(error)")
                        self.handleError(error)
                    }
                }
            }
        }
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording,
              let videoOutput = videoOutput else {
            throw VideoCaptureError.notRecording
        }
        
        print("📷 Stopping recording")
        print("📷 Preview layer state:")
        if let previewLayer = previewLayer {
            print("📷 - Has preview layer")
            print("📷 - Connection enabled: \(String(describing: previewLayer.connection?.isEnabled))")
            print("📷 - Frame: \(previewLayer.frame)")
            print("📷 - Session running: \(String(describing: previewLayer.session?.isRunning))")
        } else {
            print("📷 - No preview layer")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            completion = { result in
                switch result {
                case .success(let url):
                    print("📷 Recording stopped successfully")
                    continuation.resume(returning: url)
                case .failure(let error):
                    print("📷 Recording stopped with error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            // Ensure preview continues during and after stopping
            if let previewLayer = previewLayer {
                print("📷 Ensuring preview layer stays active")
                previewLayer.connection?.isEnabled = true
                
                // Try to restart the session if needed
                if let session = captureSession, !session.isRunning {
                    print("📷 Restarting capture session")
                    sessionQueue.async {
                        session.startRunning()
                    }
                }
            }
            
            videoOutput.stopRecording()
        }
    }
    
    // Make cleanup nonisolated
    nonisolated func cleanup() {
        print("📷 Cleaning up camera resources")
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            
            Task { @MainActor [weak self] in
                self?.previewView = nil
                self?.previewLayer = nil
                self?.captureSession = nil
                self?.videoOutput = nil
            }
        }
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorization() async {
        print("📷 Checking camera authorization")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        isAuthorized = status == .authorized
        print("📷 Current authorization status: \(status.rawValue)")
        
        if isAuthorized {
            print("📷 Already authorized, setting up capture session")
            await setupCaptureSession()
        } else {
            print("📷 Not authorized")
        }
    }
    
    private func setupCaptureSession() async {
        print("📷 Beginning capture session setup")
        do {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard let self = self else {
                    print("📷 Setup failed: Self is nil")
                    continuation.resume(throwing: VideoCaptureError.notReady)
                    return
                }
                
                self.sessionQueue.async {
                    print("📷 Configuring session on session queue")
                    // Stop existing session
                    if let existingSession = self.captureSession {
                        existingSession.stopRunning()
                        // Remove all inputs and outputs
                        for input in existingSession.inputs {
                            existingSession.removeInput(input)
                        }
                        for output in existingSession.outputs {
                            existingSession.removeOutput(output)
                        }
                        print("📷 Cleaned up existing session")
                    }
                    
                    // Create new session
                    let session = AVCaptureSession()
                    session.beginConfiguration()
                    print("📷 Created new capture session")
                    
                    // Set session preset for high quality
                    session.sessionPreset = .high
                    
                    do {
                        // Get current camera position
                        let cameraPosition = { @MainActor in
                            return self.currentCamera
                        }()
                        print("📷 Setting up camera position: \(cameraPosition)")
                        
                        // Add video input
                        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                      for: .video,
                                                                      position: cameraPosition) else {
                            print("📷 Failed to get video device")
                            throw VideoCaptureError.deviceNotAvailable
                        }
                        
                        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                        guard session.canAddInput(videoInput) else {
                            print("📷 Cannot add video input")
                            throw VideoCaptureError.deviceNotAvailable
                        }
                        session.addInput(videoInput)
                        print("📷 Added video input")
                        
                        // Add audio input
                        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                            print("📷 Failed to get audio device")
                            throw VideoCaptureError.audioNotAvailable
                        }
                        
                        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                        guard session.canAddInput(audioInput) else {
                            print("📷 Cannot add audio input")
                            throw VideoCaptureError.audioNotAvailable
                        }
                        session.addInput(audioInput)
                        print("📷 Added audio input")
                        
                        // Add video output
                        let output = AVCaptureMovieFileOutput()
                        guard session.canAddOutput(output) else {
                            print("📷 Cannot add video output")
                            throw VideoCaptureError.outputNotAvailable
                        }
                        session.addOutput(output)
                        print("📷 Added video output")
                        
                        // Configure video orientation
                        if let connection = output.connection(with: .video) {
                            if #available(iOS 17.0, *) {
                                if connection.isVideoRotationAngleSupported(90) {
                                    connection.videoRotationAngle = 90 // Portrait
                                    print("📷 Set video rotation angle to 90")
                                }
                            } else {
                                if connection.isVideoOrientationSupported {
                                    connection.videoOrientation = .portrait
                                    print("📷 Set video orientation to portrait")
                                }
                            }
                            if connection.isVideoMirroringSupported {
                                connection.isVideoMirrored = (cameraPosition == .front)
                                print("📷 Set video mirroring: \(cameraPosition == .front)")
                            }
                        }
                        
                        // Create preview layer
                        let preview = AVCaptureVideoPreviewLayer(session: session)
                        preview.videoGravity = .resizeAspectFill
                        if #available(iOS 17.0, *) {
                            preview.connection?.videoRotationAngle = 90 // Portrait
                        } else {
                            preview.connection?.videoOrientation = .portrait
                        }
                        print("📷 Created and configured preview layer")
                        
                        // Update properties on main thread
                        Task { @MainActor in
                            self.videoOutput = output
                            self.previewLayer = preview
                            self.captureSession = session
                            print("📷 Updated main thread properties")
                            // Call completion if set
                            if let completion = self.setupCompletion {
                                print("📷 Calling setup completion")
                                completion()
                                self.setupCompletion = nil
                            }
                        }
                        
                        // Commit configuration
                        session.commitConfiguration()
                        print("📷 Committed session configuration")
                        
                        // Start running on session queue
                        session.startRunning()
                        print("📷 Started capture session")
                        
                        continuation.resume()
                    } catch {
                        print("📷 Setup error: \(error)")
                        Task { @MainActor in
                            self.handleError(error)
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            print("📷 Setup failed with error: \(error)")
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoCaptureService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                              didFinishRecordingTo outputFileURL: URL,
                              from connections: [AVCaptureConnection],
                              error: Error?) {
        Task { @MainActor in
            print("📷 Recording delegate called")
            
            // Stop timer and reset recording state
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingStartTime = nil
            self.recordingDuration = 0
            self.isRecording = false
            
            // Ensure preview layer stays active
            if let previewLayer = self.previewLayer {
                print("📷 Ensuring preview layer remains active")
                previewLayer.connection?.isEnabled = true
                
                // Force a layout update
                if let view = self.previewView {
                    previewLayer.frame = view.bounds
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    CATransaction.flush()
                }
            }
            
            // Handle result
            if let error = error {
                print("📷 Recording finished with error: \(error)")
                self.completion?(.failure(error))
            } else {
                print("📷 Recording finished successfully")
                self.completion?(.success(outputFileURL))
            }
            self.completion = nil
        }
    }
}

// MARK: - Errors

enum VideoCaptureError: LocalizedError {
    case notReady
    case notRecording
    case deviceNotAvailable
    case audioNotAvailable
    case outputNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Camera is not ready"
        case .notRecording:
            return "No active recording"
        case .deviceNotAvailable:
            return "Camera device is not available"
        case .audioNotAvailable:
            return "Audio device is not available"
        case .outputNotAvailable:
            return "Video output is not available"
        }
    }
} 
