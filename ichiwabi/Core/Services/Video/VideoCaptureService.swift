import Foundation
import AVFoundation
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
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var completion: ((Result<URL, Error>) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        Task {
            await checkAuthorization()
        }
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .authorized:
            isAuthorized = true
        default:
            isAuthorized = false
        }
        
        if isAuthorized {
            await setupCaptureSession()
        }
    }
    
    func startPreview(in view: UIView) {
        guard let previewLayer = previewLayer else { return }
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    func switchCamera() {
        guard !isRecording else { return }
        currentCamera = currentCamera == .front ? .back : .front
        Task {
            await setupCaptureSession()
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
                guard let self = self else { return }
                guard let startTime = self.recordingStartTime else { return }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordingDuration = duration
                
                // Stop recording if max duration reached
                if duration >= maxDuration {
                    do {
                        _ = try await self.stopRecording()
                    } catch {
                        print("Failed to stop recording at max duration: \(error)")
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
        
        return try await withCheckedThrowingContinuation { continuation in
            completion = { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            videoOutput.stopRecording()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        isAuthorized = status == .authorized
        
        if isAuthorized {
            await setupCaptureSession()
        }
    }
    
    private func setupCaptureSession() async {
        // Stop existing session
        captureSession?.stopRunning()
        
        // Create new session
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: currentCamera),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            handleError(VideoCaptureError.deviceNotAvailable)
            return
        }
        session.addInput(videoInput)
        
        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioInput) else {
            handleError(VideoCaptureError.audioNotAvailable)
            return
        }
        session.addInput(audioInput)
        
        // Add video output
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            handleError(VideoCaptureError.outputNotAvailable)
            return
        }
        session.addOutput(output)
        videoOutput = output
        
        // Create preview layer
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        previewLayer = preview
        
        // Commit configuration
        session.commitConfiguration()
        captureSession = session
        
        // Start running
        session.startRunning()
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
            // Stop timer
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingStartTime = nil
            self.recordingDuration = 0
            self.isRecording = false
            
            // Handle result
            if let error = error {
                self.completion?(.failure(error))
            } else {
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