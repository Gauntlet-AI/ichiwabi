import SwiftUI
import AVKit

struct DreamDetailsView: View {
    @StateObject private var viewModel: DreamDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        let oneMonthAhead = calendar.date(byAdding: .month, value: 1, to: now)!
        return sixMonthsAgo...oneMonthAhead
    }()
    
    init(videoURL: URL, dreamService: DreamService, userId: String) {
        _viewModel = StateObject(wrappedValue: DreamDetailsViewModel(
            videoURL: videoURL,
            dreamService: dreamService,
            userId: userId
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.title)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Dream Title")
                } footer: {
                    Text("Give your dream a memorable title")
                }
                
                Section {
                    DatePicker(
                        "Dream Date",
                        selection: $viewModel.dreamDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                } header: {
                    Text("When did you have this dream?")
                }
                
                Section {
                    if viewModel.isTranscribing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Transcribing audio...")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    TextEditor(text: $viewModel.transcript)
                        .frame(minHeight: 100)
                } header: {
                    Text("Dream Description")
                } footer: {
                    Text("Describe your dream or edit the auto-generated transcript")
                }
                
                Section {
                    VideoPlayer(player: AVPlayer(url: viewModel.videoURL))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } header: {
                    Text("Dream Recording")
                }
            }
            .navigationTitle("Dream Details")
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
                            try? await viewModel.saveDream()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.title.isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    VStack {
                        ProgressView("Saving dream...")
                        if viewModel.uploadProgress > 0 {
                            Text("\(Int(viewModel.uploadProgress * 100))% uploaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
            }
        }
    }
} 