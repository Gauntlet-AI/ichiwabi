import SwiftUI
import PhotosUI

struct DreamRecorderView: View {
    @StateObject private var videoCaptureService = VideoCaptureService()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingPermissionAlert = false
    @State private var recordedVideoURL: URL?
    @State private var selectedVideoURL: URL?
    @State private var showingTrimmer = false
    @State private var isSelectingFromLibrary = false
    @Environment(\.dismiss) private var dismiss
    let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview - only show if not selecting from library
                if videoCaptureService.isAuthorized && !isSelectingFromLibrary {
                    CameraPreviewView(videoCaptureService: videoCaptureService)
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Controls overlay
                VStack {
                    // Top controls
                    HStack {
                        Button {
                            if videoCaptureService.isRecording {
                                Task {
                                    _ = try? await videoCaptureService.stopRecording()
                                }
                            }
                            videoCaptureService.cleanup()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .bold()
                        }
                        
                        Spacer()
                        
                        if !videoCaptureService.isRecording && !isSelectingFromLibrary {
                            HStack(spacing: 24) {
                                Button {
                                    videoCaptureService.toggleLowLightMode()
                                } label: {
                                    Image(systemName: videoCaptureService.isLowLightModeEnabled ? "moon.fill" : "moon")
                                        .font(.title2)
                                }
                                
                                Button {
                                    videoCaptureService.switchCamera()
                                } label: {
                                    Image(systemName: "camera.rotate")
                                        .font(.title2)
                                }
                            }
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Recording duration
                    if videoCaptureService.isRecording {
                        Text(timeString(from: videoCaptureService.recordingDuration))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .padding(.vertical)
                    }
                    
                    // Bottom controls
                    HStack(spacing: 40) {
                        // Library picker
                        if !videoCaptureService.isRecording {
                            PhotosPicker(selection: $selectedItem,
                                       matching: .videos,
                                       photoLibrary: .shared()) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .onChange(of: selectedItem) { oldValue, newValue in
                                isSelectingFromLibrary = newValue != nil
                                if newValue != nil {
                                    // Clean up camera resources when selecting from library
                                    videoCaptureService.cleanup()
                                }
                            }
                        }
                        
                        // Record button - only show if not selecting from library
                        if !isSelectingFromLibrary {
                            Button {
                                handleRecordButton()
                            } label: {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 72, height: 72)
                                    .overlay {
                                        Circle()
                                            .fill(videoCaptureService.isRecording ? .white : .red)
                                            .frame(width: 60, height: 60)
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(.black)
            .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Please allow camera access in Settings to record your dreams.")
            }
            .alert("Error", isPresented: .constant(videoCaptureService.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    videoCaptureService.errorMessage = nil
                }
            } message: {
                if let errorMessage = videoCaptureService.errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                // Only request camera authorization if we're not selecting from library
                if !isSelectingFromLibrary && !videoCaptureService.isAuthorized {
                    await videoCaptureService.requestAuthorization()
                    if !videoCaptureService.isAuthorized {
                        showingPermissionAlert = true
                    }
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let url = try? await saveVideoToTemp(data: data) {
                        selectedVideoURL = url
                        showingTrimmer = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingTrimmer) {
                if let url = selectedVideoURL ?? recordedVideoURL {
                    VideoTrimmerView(videoURL: url, userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissRecorder"))) { _ in
            if videoCaptureService.isRecording {
                Task {
                    _ = try? await videoCaptureService.stopRecording()
                }
            }
            videoCaptureService.cleanup()
            dismiss()
        }
        .onDisappear {
            // Only cleanup if we're not showing the trimmer
            if !showingTrimmer {
                if videoCaptureService.isRecording {
                    Task {
                        _ = try? await videoCaptureService.stopRecording()
                    }
                }
                videoCaptureService.cleanup()
            }
        }
    }
    
    private func handleRecordButton() {
        Task {
            if videoCaptureService.isRecording {
                if let url = try? await videoCaptureService.stopRecording() {
                    // Ensure we're on the main thread for UI updates
                    await MainActor.run {
                        recordedVideoURL = url
                        showingTrimmer = true
                    }
                }
            } else {
                try? await videoCaptureService.startRecording()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveVideoToTemp(data: Data) async throws -> URL {
        await MainActor.run {
            // Ensure we're on the main thread when updating UI state
            isSelectingFromLibrary = false
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
} 