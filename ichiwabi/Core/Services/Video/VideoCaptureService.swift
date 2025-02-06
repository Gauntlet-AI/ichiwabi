@preconcurrency import Foundation
@preconcurrency import AVFoundation
import UIKit
import SwiftUI

// MARK: - Main Class
@MainActor
final class VideoCaptureService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isAuthorized = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentCamera: AVCaptureDevice.Position = .front
    @Published private(set) var isLowLightModeEnabled = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    static let maxDuration: TimeInterval = 180 // 3 minutes
    
    // MARK: - Private Properties
    private var isBeingCleaned = false
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
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
    
// MARK: - Authorization
extension VideoCaptureService {
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
}

// MARK: - Session Setup
private extension VideoCaptureService {
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
                    self.configureSession(continuation: continuation)
                }
            }
        } catch {
            print("📷 Setup failed with error: \(error)")
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    private func configureSession(continuation: CheckedContinuation<Void, Error>) {
        print("📷 Configuring session on session queue")
        cleanupExistingSession()
        
        // Create new session
        let session = AVCaptureSession()
        session.beginConfiguration()
        print("📷 Created new capture session")
        
        // Set session preset for high quality
        session.sessionPreset = .high
        
        do {
            try configureSessionComponents(session: session)
            
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
    
    private func cleanupExistingSession() {
        if let existingSession = captureSession {
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
    }
    
    private func configureSessionComponents(session: AVCaptureSession) throws {
        // Get current camera position
        let cameraPosition = { @MainActor in
            return self.currentCamera
        }()
        print("📷 Setting up camera position: \(cameraPosition)")
        
        // Configure video
        let videoDevice = try configureVideoInput(session: session, position: cameraPosition)
        try configureLowLightSettings(for: videoDevice)
        
        // Configure audio
        try configureAudioInput(session: session)
        
        // Configure output
        let output = try configureVideoOutput(session: session)
        
        // Create and configure preview layer
        let preview = createPreviewLayer(for: session)
        
        // Update properties on main thread
        Task { @MainActor in
            self.videoOutput = output
            self.previewLayer = preview
            self.captureSession = session
            print("📷 Updated main thread properties")
            
            if let completion = self.setupCompletion {
                print("📷 Calling setup completion")
                completion()
                self.setupCompletion = nil
            }
        }
    }
    
    private func configureVideoInput(session: AVCaptureSession, position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: position) else {
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
        
        return videoDevice
    }
    
    private func configureAudioInput(session: AVCaptureSession) throws {
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
    }
    
    private func configureVideoOutput(session: AVCaptureSession) throws -> AVCaptureMovieFileOutput {
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            print("📷 Cannot add video output")
            throw VideoCaptureError.outputNotAvailable
        }
        session.addOutput(output)
        print("📷 Added video output")
        
        configureVideoOrientation(for: output)
        
        return output
    }
    
    private func configureVideoOrientation(for output: AVCaptureMovieFileOutput) {
        guard let connection = output.connection(with: .video) else { return }
        
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
            connection.isVideoMirrored = (currentCamera == .front)
            print("📷 Set video mirroring: \(currentCamera == .front)")
        }
    }
    
    private func createPreviewLayer(for session: AVCaptureSession) -> AVCaptureVideoPreviewLayer {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        if #available(iOS 17.0, *) {
            preview.connection?.videoRotationAngle = 90 // Portrait
        } else {
            preview.connection?.videoOrientation = .portrait
        }
        print("📷 Created and configured preview layer")
        return preview
    }
    
    private func configureLowLightSettings(for device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = isLowLightModeEnabled
        }
        device.unlockForConfiguration()
    }
}

// MARK: - Preview Management
extension VideoCaptureService {
    func startPreview(in view: UIView) {
        print("📷 Attempting to start preview")
        previewView = view
        
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("📷 View bounds are zero, waiting for layout")
            return
        }
        
        configurePreviewLayer(in: view)
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
    
    private func configurePreviewLayer(in view: UIView) {
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📷 Starting preview setup")
            
            self.removeExistingPreviewLayers(from: view)
            self.createAndConfigurePreviewLayer(in: view)
        }
    }
    
    private func removeExistingPreviewLayers(from view: UIView) {
        view.layer.sublayers?.forEach { layer in
            if layer is AVCaptureVideoPreviewLayer {
                print("📷 Removing existing preview layer")
                layer.removeFromSuperlayer()
            }
        }
    }
    
    private func createAndConfigurePreviewLayer(in view: UIView) {
        if self.previewLayer == nil, let session = self.captureSession {
            print("📷 Creating new preview layer")
            let newLayer = AVCaptureVideoPreviewLayer(session: session)
            newLayer.videoGravity = .resizeAspectFill
            
            configurePreviewConnection(newLayer)
            
            self.previewLayer = newLayer
        }
        
        if let previewLayer = self.previewLayer {
            setupPreviewLayerInView(previewLayer, view: view)
        } else {
            setupCompletionHandler(for: view)
        }
    }
    
    private func configurePreviewConnection(_ layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection else { return }
        
        connection.preferredVideoStabilizationMode = .off
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 90
        } else {
            connection.videoOrientation = .portrait
        }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = (self.currentCamera == .front)
    }
    
    private func setupPreviewLayerInView(_ previewLayer: AVCaptureVideoPreviewLayer, view: UIView) {
        print("📷 Configuring preview layer frame: \(view.bounds)")
        previewLayer.frame = view.bounds
        previewLayer.connection?.isEnabled = true
        
        // Force layer to be renderable
        previewLayer.drawsAsynchronously = false
        view.layer.isOpaque = true
        view.backgroundColor = .black
        
        // Add preview layer
        view.layer.insertSublayer(previewLayer, at: 0)
        print("📷 Added preview layer to view")
        
        forceImmediateLayout(view)
        startCaptureSessionIfNeeded()
    }
    
    private func forceImmediateLayout(_ view: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        CATransaction.commit()
    }
    
    private func startCaptureSessionIfNeeded() {
        guard let session = self.captureSession else { return }
        
        if !session.isRunning {
            print("📷 Starting capture session")
            self.sessionQueue.async {
                session.startRunning()
                print("📷 Capture session started")
                
                // Force a preview layer update on the main thread
                DispatchQueue.main.async {
                    self.previewLayer?.setNeedsDisplay()
                }
            }
        } else {
            print("📷 Session already running")
            // Force a preview layer update
            self.previewLayer?.setNeedsDisplay()
        }
    }
    
    private func setupCompletionHandler(for view: UIView) {
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

// MARK: - Camera Control
extension VideoCaptureService {
    func toggleLowLightMode() {
        guard let videoDevice = getCurrentVideoDevice() else { return }
        
        do {
            try videoDevice.lockForConfiguration()
            
            // Toggle low light boost mode if available
            if videoDevice.isLowLightBoostSupported {
                videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = !videoDevice.automaticallyEnablesLowLightBoostWhenAvailable
                isLowLightModeEnabled = videoDevice.automaticallyEnablesLowLightBoostWhenAvailable
            }
            
            // Adjust ISO and exposure for low light
            if isLowLightModeEnabled {
                configureForLowLight(videoDevice)
            } else {
                resetToDefaultSettings(videoDevice)
            }
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("📷 Failed to configure low light mode: \(error)")
            errorMessage = "Failed to configure camera settings"
        }
    }
    
    private func configureForLowLight(_ device: AVCaptureDevice) {
        // Set custom exposure duration for low light
        let maxDuration = device.activeFormat.maxExposureDuration
        let currentDuration = device.exposureDuration
        
        // Gradually increase exposure duration if needed
        if currentDuration < maxDuration {
            device.setExposureModeCustom(
                duration: maxDuration,
                iso: device.activeFormat.maxISO
            )
        }
        
        // Enable auto white balance for better color in low light
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }
    
    private func resetToDefaultSettings(_ device: AVCaptureDevice) {
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }
    
    private func getCurrentVideoDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera,
                                     for: .video,
                                     position: currentCamera)
    }
    
    // Make cleanup nonisolated
    nonisolated func cleanup() {
        print("📷 Starting cleanup process...")
        print("📷 Current thread: \(Thread.current.description)")
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Use instance flag to prevent multiple cleanups
            guard !self.isBeingCleaned else {
                print("📷 Cleanup already in progress, skipping")
                return
            }
            self.isBeingCleaned = true
            
            self.sessionQueue.async { [weak self] in
                guard let self = self else {
                    print("📷 Self is nil in session queue")
                    Task { @MainActor in
                        self?.isBeingCleaned = false
                    }
                    return
                }
                
                print("📷 Executing cleanup on session queue")
                
                // Stop recording if needed
                if self.isRecording {
                    print("📷 Stopping active recording")
                    self.videoOutput?.stopRecording()
                }
                
                // Stop the session
                if let session = self.captureSession {
                    print("📷 Stopping capture session")
                    if session.isRunning {
                        session.stopRunning()
                    }
                }
                
                // Clean up on main thread
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        print("📷 Self is nil in main actor task")
                        return
                    }
                    
                    print("📷 Starting main thread cleanup")
                    
                    // Stop and remove timer
                    if let timer = self.recordingTimer {
                        print("📷 Invalidating timer")
                        timer.invalidate()
                    }
                    self.recordingTimer = nil
                    
                    // Reset recording state
                    print("📷 Resetting recording state")
                    self.recordingStartTime = nil
                    self.recordingDuration = 0
                    self.isRecording = false
                    
                    // Clear completion handlers
                    print("📷 Clearing completion handlers")
                    self.completion = nil
                    self.setupCompletion = nil
                    
                    // Remove preview layer
                    if let previewLayer = self.previewLayer {
                        print("📷 Removing preview layer")
                        DispatchQueue.main.async {
                            previewLayer.removeFromSuperlayer()
                        }
                    }
                    
                    // Clear references in specific order
                    print("📷 Clearing references")
                    self.previewView = nil
                    self.previewLayer = nil
                    self.videoOutput = nil
                    self.captureSession = nil
                    
                    print("📷 Cleanup completed successfully")
                    self.isBeingCleaned = false
                }
            }
        }
    }
}

// MARK: - Recording Management
extension VideoCaptureService {
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
        
        startRecordingTimer()
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording,
              let videoOutput = videoOutput else {
            throw VideoCaptureError.notRecording
        }
        
        print("📷 Stopping recording")
        logPreviewLayerState()
        
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
            
            ensurePreviewContinues()
            videoOutput.stopRecording()
        }
    }
    
    private func startRecordingTimer() {
        let maxDuration = Self.maxDuration
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
    
    private func logPreviewLayerState() {
        print("📷 Preview layer state:")
        if let previewLayer = previewLayer {
            print("📷 - Has preview layer")
            print("📷 - Connection enabled: \(String(describing: previewLayer.connection?.isEnabled))")
            print("📷 - Frame: \(previewLayer.frame)")
            print("📷 - Session running: \(String(describing: previewLayer.session?.isRunning))")
        } else {
            print("📷 - No preview layer")
        }
    }
    
    private func ensurePreviewContinues() {
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
