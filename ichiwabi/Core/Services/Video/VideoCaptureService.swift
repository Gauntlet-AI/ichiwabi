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
                    do {
                        try self.configureSession()
                        continuation.resume()
                    } catch {
                        print("📷 Setup failed with error: \(error)")
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
    
    private func configureSession() throws {
        print("📷 Configuring session on session queue")
        
        // Ensure we're on the session queue
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        
        cleanupExistingSession()
        
        // Create new session
        let session = AVCaptureSession()
        print("📷 Created new capture session")
        
        // Configure session on session queue
        session.beginConfiguration()
        
        // Set session preset for high quality
        session.sessionPreset = .high
        
        do {
            // Get current camera position synchronously
            let cameraPosition = currentCamera
            try configureSessionComponents(session: session, position: cameraPosition)
            
            // Commit configuration while still on session queue
            session.commitConfiguration()
            print("📷 Committed session configuration")
            
            // Start running on session queue
            session.startRunning()
            print("📷 Started capture session")
            
            // Update the session property on main thread
            Task { @MainActor in
                self.captureSession = session
            }
            
        } catch {
            print("📷 Setup error: \(error)")
            session.commitConfiguration() // Ensure we commit even on error
            throw error
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
    
    private func configureSessionComponents(session: AVCaptureSession, position: AVCaptureDevice.Position) throws {
        // Ensure we're on the session queue
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        
        print("📷 Setting up camera position: \(position)")
        
        // Configure video
        let videoDevice = try configureVideoInput(session: session, position: position)
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
        Task { @MainActor in
            self.previewView = view
            
            guard view.bounds.width > 0 && view.bounds.height > 0 else {
                print("📷 View bounds are zero, waiting for layout")
                return
            }
            
            configurePreviewLayer(in: view)
        }
    }
    
    func switchCamera() {
        Task { @MainActor in
            guard !isRecording else { return }
            print("📷 Switching camera")
            
            // Store current view
            let currentView = previewView
            
            sessionQueue.async {
                // Stop current session
                if let session = self.captureSession {
                    session.stopRunning()
                }
                
                Task { @MainActor in
                    // Update camera position
                    self.currentCamera = self.currentCamera == .front ? .back : .front
                    
                    // Setup new session
                    Task {
                        await self.setupCaptureSession()
                        if let view = currentView {
                            await self.startPreview(in: view)
                        }
                    }
                }
            }
        }
    }
    
    private func configurePreviewLayer(in view: UIView) {
        Task { @MainActor in
            print("📷 Starting preview setup")
            
            removeExistingPreviewLayers(from: view)
            createAndConfigurePreviewLayer(in: view)
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
        Task { @MainActor in
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
            
            // Start session on background queue if needed
            if let session = self.captureSession, !session.isRunning {
                sessionQueue.async {
                    if !session.isRunning {
                        session.startRunning()
                        print("📷 Started capture session for preview")
                    }
                }
            }
        }
    }
    
    private func configurePreviewConnection(_ layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection else { return }
        
        sessionQueue.async {
            connection.preferredVideoStabilizationMode = .off
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (self.currentCamera == .front)
        }
    }
    
    private func setupPreviewLayerInView(_ previewLayer: AVCaptureVideoPreviewLayer, view: UIView) {
        print("📷 Configuring preview layer frame: \(view.bounds)")
        
        // Configure layer properties on main thread
        previewLayer.frame = view.bounds
        previewLayer.connection?.isEnabled = true
        
        // Force layer to be renderable
        previewLayer.drawsAsynchronously = true  // Enable asynchronous drawing
        view.layer.isOpaque = true
        view.backgroundColor = .black
        
        // Add preview layer
        view.layer.insertSublayer(previewLayer, at: 0)
        print("📷 Added preview layer to view")
        
        forceImmediateLayout(view)
        
        // Start session on background queue if needed
        if let session = captureSession, !session.isRunning {
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                    print("📷 Started capture session for preview")
                }
            }
        }
    }
    
    private func forceImmediateLayout(_ view: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        CATransaction.commit()
        
        // Force a display update
        view.layer.displayIfNeeded()
    }
    
    private func startCaptureSessionIfNeeded() {
        Task { @MainActor in
            guard let session = self.captureSession else { return }
            let capturedSession = session
            let capturedSessionQueue = self.sessionQueue
            
            if !capturedSession.isRunning {
                print("📷 Starting capture session")
                capturedSessionQueue.async {
                    if !capturedSession.isRunning {
                        capturedSession.startRunning()
                        print("📷 Capture session started")
                        
                        // Force a preview layer update on the main thread
                        Task { @MainActor in
                            self.previewLayer?.setNeedsDisplay()
                        }
                    }
                }
            } else {
                print("📷 Session already running")
                // Force a preview layer update
                self.previewLayer?.setNeedsDisplay()
            }
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
            
            // Capture values that need to be accessed in the closure
            let isCurrentlyRecording = self.isRecording
            let currentVideoOutput = self.videoOutput
            let currentSession = self.captureSession
            let queue = self.sessionQueue
            
            queue.async {
                // Stop recording if needed
                if isCurrentlyRecording {
                    print("📷 Stopping active recording")
                    currentVideoOutput?.stopRecording()
                }
                
                // Stop the session
                if let session = currentSession {
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
                        previewLayer.removeFromSuperlayer()
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
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let videoOutput = self.videoOutput else {
                    continuation.resume(throwing: VideoCaptureError.notReady)
                    return
                }
                
                // Create temporary URL for recording
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(UUID().uuidString).mov"
                let tempURL = tempDir.appendingPathComponent(fileName)
                
                // Capture necessary values before starting recording
                let capturedVideoOutput = videoOutput
                
                sessionQueue.async {
                    capturedVideoOutput.startRecording(to: tempURL, recordingDelegate: self)
                    
                    Task { @MainActor in
                        self.recordingURL = tempURL
                        self.isRecording = true
                        self.recordingStartTime = Date()
                        self.startRecordingTimer()
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func stopRecording() async throws -> URL? {
        print("📷 Stopping recording")
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let output = self.videoOutput, output.isRecording else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let currentRecordingURL = self.recordingURL
                let capturedOutput = output
                
                sessionQueue.async {
                    capturedOutput.stopRecording()
                    
                    Task { @MainActor in
                        self.isRecording = false
                        self.recordingDuration = 0
                        self.recordingTimer?.invalidate()
                        self.recordingTimer = nil
                        
                        continuation.resume(returning: currentRecordingURL)
                    }
                }
            }
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
        Task { @MainActor in
            print("📷 Preview layer state:")
            if let previewLayer = self.previewLayer {
                print("📷 - Has preview layer")
                print("📷 - Connection enabled: \(String(describing: previewLayer.connection?.isEnabled))")
                print("📷 - Frame: \(previewLayer.frame)")
                print("📷 - Session running: \(String(describing: previewLayer.session?.isRunning))")
            } else {
                print("📷 - No preview layer")
            }
        }
    }
    
    private func ensurePreviewContinues() {
        Task { @MainActor in
            if let previewLayer = self.previewLayer {
                print("📷 Ensuring preview layer stays active")
                previewLayer.connection?.isEnabled = true
                
                // Try to restart the session if needed
                if let session = self.captureSession, !session.isRunning {
                    print("📷 Restarting capture session")
                    let capturedSession = session
                    let capturedSessionQueue = self.sessionQueue
                    
                    capturedSessionQueue.async {
                        if !capturedSession.isRunning {
                            capturedSession.startRunning()
                        }
                    }
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
