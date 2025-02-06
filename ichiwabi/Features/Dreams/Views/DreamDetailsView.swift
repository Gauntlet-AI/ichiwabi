import SwiftUI
import AVKit
import SwiftData

struct DreamDetailsView: View {
    let videoURL: URL
    let userId: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: DreamDetailsViewModel
    @State private var showingError = false
    @State private var player: AVPlayer?
    
    init(videoURL: URL, userId: String) {
        self.videoURL = videoURL
        self.userId = userId
        
        // Initialize viewModel with a temporary DreamService
        let tempContext: ModelContext
        do {
            let container = try ModelContainer(for: Dream.self)
            tempContext = ModelContext(container)
        } catch {
            print("Failed to create temporary container: \(error)")
            // Fallback to an in-memory container
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(for: Dream.self, configurations: config)
                tempContext = ModelContext(container)
            } catch {
                fatalError("Failed to create even in-memory container: \(error)")
            }
        }
        
        _viewModel = StateObject(wrappedValue: DreamDetailsViewModel(
            videoURL: videoURL,
            dreamService: DreamService(modelContext: tempContext, userId: userId),
            userId: userId
        ))
    }
    
    var body: some View {
        Form {
            Section {
                // Video preview
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxHeight: 300)
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: 300)
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
            
            if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1 {
                Section {
                    ProgressView("Uploading video...", value: viewModel.uploadProgress, total: 1.0)
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
                .disabled(viewModel.isLoading || viewModel.title.isEmpty)
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
            if viewModel.isLoading {
                ProgressView("Saving dream...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .onAppear {
            // Update the DreamService with the actual modelContext
            viewModel.updateDreamService(DreamService(modelContext: modelContext, userId: userId))
            
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