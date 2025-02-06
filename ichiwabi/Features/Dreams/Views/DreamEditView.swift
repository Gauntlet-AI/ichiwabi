import SwiftUI
import SwiftData

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
    
    init(dream: Dream) {
        self.dream = dream
        _selectedDate = State(initialValue: dream.dreamDate)
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
            try modelContext.save()
            dismiss()
        } catch {
            self.error = error
        }
    }
} 