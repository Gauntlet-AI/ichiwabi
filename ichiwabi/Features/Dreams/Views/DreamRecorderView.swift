import SwiftUI
import PhotosUI

struct DreamRecorderView: View {
    @StateObject private var videoCaptureService = VideoCaptureService()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingPermissionAlert = false
    @State private var recordedVideoURL: URL?
    @State private var selectedVideoURL: URL?
    @State private var showingTrimmer = false
    @Environment(\.dismiss) private var dismiss
    let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                if videoCaptureService.isAuthorized {
                    CameraPreviewView(videoCaptureService: videoCaptureService)
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Controls overlay
                VStack {
                    // Top controls
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .bold()
                        }
                        
                        Spacer()
                        
                        if !videoCaptureService.isRecording {
                            Button {
                                videoCaptureService.switchCamera()
                            } label: {
                                Image(systemName: "camera.rotate")
                                    .font(.title2)
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
                        }
                        
                        // Record button
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
            .task {
                if !videoCaptureService.isAuthorized {
                    await videoCaptureService.requestAuthorization()
                    if !videoCaptureService.isAuthorized {
                        showingPermissionAlert = true
                    }
                }
            }
        }
    }
    
    private func handleRecordButton() {
        Task {
            if videoCaptureService.isRecording {
                if let url = try? await videoCaptureService.stopRecording() {
                    recordedVideoURL = url
                    showingTrimmer = true
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
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
} 