import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var filterDate: Date
    @State private var dreamToEdit: Dream?
    @State private var dreamToPlay: Dream?
    private let calendar = Calendar.current
    
    @Query(sort: \Dream.dreamDate) private var allDreams: [Dream]
    
    private var dreams: [Dream] {
        let startOfDay = calendar.startOfDay(for: filterDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return allDreams.filter { dream in
            dream.dreamDate >= startOfDay && dream.dreamDate < endOfDay
        }
    }
    
    init(filterDate: Date) {
        _filterDate = State(initialValue: filterDate)
    }
    
    var body: some View {
        List {
            ForEach(dreams) { dream in
                DreamCell(dream: dream)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🎥 Tapped dream: \(dream.title)")
                        print("🎥 Video URL: \(dream.videoURL)")
                        if !dream.videoURL.absoluteString.isEmpty {
                            print("🎥 Playing video")
                            dreamToPlay = dream
                        } else {
                            print("🎥 Editing dream")
                            dreamToEdit = dream
                        }
                    }
                    .contextMenu {
                        Button {
                            dreamToEdit = dream
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        if !dream.videoURL.absoluteString.isEmpty {
                            Button {
                                dreamToPlay = dream
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                        }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Button {
                        moveToPreviousDay()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(filterDate.formatted(date: .long, time: .omitted))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button {
                        moveToNextDay()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
        .overlay {
            if dreams.isEmpty {
                ContentUnavailableView(
                    "No Dreams",
                    systemImage: "moon.zzz",
                    description: Text("No dreams recorded for this date")
                )
            }
        }
        .sheet(item: $dreamToEdit) { dream in
            NavigationStack {
                DreamEditView(dream: dream)
            }
        }
        .sheet(item: $dreamToPlay) { dream in
            NavigationStack {
                DreamPlaybackView(dream: dream, modelContext: modelContext)
            }
        }
    }
    
    private func moveToPreviousDay() {
        if let newDate = calendar.date(byAdding: .day, value: -1, to: filterDate) {
            filterDate = newDate
        }
    }
    
    private func moveToNextDay() {
        if let newDate = calendar.date(byAdding: .day, value: 1, to: filterDate) {
            filterDate = newDate
        }
    }
}

