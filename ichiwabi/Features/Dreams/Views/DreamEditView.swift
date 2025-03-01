import SwiftUI
import SwiftData
import FirebaseFirestore

struct DreamEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var dream: Dream
    @State private var selectedDate: Date
    @State private var isLoading = false
    @State private var error: Error?
    
    private let calendar = Calendar.current
    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        let oneMonthAhead = calendar.date(byAdding: .month, value: 1, to: now)!
        return sixMonthsAgo...oneMonthAhead
    }()
    
    private let dreamService: DreamService
    
    init(dream: Dream, modelContext: ModelContext) {
        self.dream = dream
        _selectedDate = State(initialValue: dream.dreamDate)
        self.dreamService = DreamService(modelContext: modelContext, userId: dream.userId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dream Details") {
                    TextField("Title", text: $dream.title)
                    
                    if let transcript = dream.transcript {
                        Text(transcript)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Date and Time") {
                    DatePicker(
                        "Dream Date",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .onChange(of: selectedDate) { oldValue, newValue in
                        // Preserve the time component while updating the date
                        let oldComponents = calendar.dateComponents([.hour, .minute], from: dream.dreamDate)
                        if var newDate = calendar.date(bySettingHour: oldComponents.hour ?? 0,
                                                     minute: oldComponents.minute ?? 0,
                                                     second: 0,
                                                     of: newValue) {
                            // Normalize to start of minute
                            newDate = calendar.date(bySetting: .second, value: 0, of: newDate) ?? newDate
                            dream.dreamDate = newDate
                        }
                    }
                    
                    DatePicker(
                        "Dream Time",
                        selection: $dream.dreamDate,
                        displayedComponents: [.hourAndMinute]
                    )
                }
                
                Section {
                    Text("Recorded on \(dream.date.formatted(date: .long, time: .shortened))")
                        .foregroundStyle(.secondary)
                    Text("Last updated \(dream.updatedAt.formatted(date: .long, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Dream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveDream()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(Theme.darkNavy)
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func saveDream() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            dream.updatedAt = Date()
            try await dreamService.updateDream(dream)
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Dream.self, configurations: config)
        
        // Create a sample dream
        let dream = Dream(
            userId: "preview_user",
            title: "Flying Dream",
            description: "I was flying over mountains...",
            date: Date(),
            videoURL: URL(string: "https://example.com/video.mp4")!,
            transcript: "I was soaring through the clouds, feeling the wind beneath my wings...",
            dreamDate: Date()
        )
        
        // Insert the dream into the container's context
        container.mainContext.insert(dream)
        
        return NavigationStack {
            DreamEditView(dream: dream, modelContext: container.mainContext)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .background(Theme.darkNavy)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 