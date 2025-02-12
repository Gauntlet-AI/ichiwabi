import SwiftUI
import AVKit
import SwiftData

struct DreamDetailsView: View {
    let videoURL: URL
    let userId: String
    let initialTitle: String?
    let trimStartTime: Double
    let trimEndTime: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingError = false
    @State private var player: AVPlayer?
    
    // Move viewModel to a StateObject property wrapper without initialization
    @StateObject private var viewModel: DreamDetailsViewModel
    
    init(videoURL: URL, userId: String, initialTitle: String? = nil, trimStartTime: Double = 0, trimEndTime: Double = 0) {
        self.videoURL = videoURL
        self.userId = userId
        self.initialTitle = initialTitle
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        
        // Create a temporary context for initialization
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let tempContext: ModelContext
        do {
            let container = try ModelContainer(for: Dream.self, configurations: config)
            tempContext = container.mainContext
        } catch {
            print("Failed to create temporary container: \(error)")
            // This is a critical error - we cannot proceed without a ModelContext
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Initialize the viewModel with the temporary context
        self._viewModel = StateObject(wrappedValue: DreamDetailsViewModel(
            videoURL: videoURL,
            dreamService: DreamService(modelContext: tempContext, userId: userId),
            userId: userId,
            initialTitle: initialTitle,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        ))
    }
    
    var body: some View {
        Form {
            Section {
                // Video preview
                if let player = player {
                    HStack {
                        Spacer()
                        VideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .frame(maxHeight: 300)
                            .onDisappear {
                                player.pause()
                            }
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets())
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                        Spacer()
                    }
                }
            }
            
            Section("Dream Details") {
                TextField("Title", text: $viewModel.title)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                
                DatePicker(
                    "Dream Date",
                    selection: $viewModel.dreamDate,
                    displayedComponents: [.date]
                )
                
                if viewModel.isTranscribing {
                    ProgressView("Transcribing video...")
                } else {
                    TextEditor(text: $viewModel.transcript)
                        .frame(minHeight: 100)
                }
            }
        }
        .navigationTitle("New Dream")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        do {
                            print("💭 Saving dream...")
                            // Update the viewModel's DreamService with the actual modelContext
                            viewModel.updateDreamService(DreamService(modelContext: modelContext, userId: userId))
                            try await viewModel.saveDream()
                            print("💭 Dream saved successfully")
                            
                            // Dismiss all the way back to home screen
                            dismiss()
                            
                            // Post notification to dismiss video trimmer
                            NotificationCenter.default.post(name: NSNotification.Name("DismissVideoTrimmer"), object: nil)
                            
                            // Post notification to dismiss dream recorder
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(name: NSNotification.Name("DismissRecorder"), object: nil)
                            }
                        } catch {
                            print("❌ Error saving dream: \(error)")
                            viewModel.error = error
                            showingError = true
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .overlay {
            if viewModel.isLoading || viewModel.uploadProgress > 0 {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        if viewModel.uploadProgress > 0 {
                            VStack(spacing: 8) {
                                ProgressView("Uploading dream...", value: viewModel.uploadProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .tint(.white)
                                    .foregroundColor(.white)
                                
                                Text("\(Int(viewModel.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .animation(.easeInOut, value: viewModel.uploadProgress)
                                
                                if viewModel.uploadProgress < 1.0 {
                                    Text("Please wait while your dream is being uploaded...")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                ProgressView("Preparing dream...")
                                    .tint(.white)
                                    .foregroundColor(.white)
                                
                                Text("Getting your dream ready...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(width: 250)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
        .onAppear {
            // Initialize player
            player = AVPlayer(url: videoURL)
            player?.play()
        }
    }
}

#Preview {
    NavigationStack {
        DreamDetailsView(
            videoURL: URL(string: "https://example.com/video.mp4")!,
            userId: "preview_user_id"
        )
    }
} 