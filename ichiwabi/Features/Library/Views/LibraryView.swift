import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dreams: [Dream]
    let filterDate: Date
    @State private var dreamToEdit: Dream?
    @State private var dreamToPlay: Dream?
    
    init(filterDate: Date) {
        self.filterDate = filterDate
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: filterDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            _dreams = Query(filter: #Predicate<Dream> { _ in false })
            return
        }
        
        _dreams = Query(
            filter: #Predicate<Dream> { dream in
                dream.dreamDate >= startOfDay && dream.dreamDate < endOfDay
            },
            sort: \Dream.dreamDate
        )
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
        .navigationTitle(filterDate.formatted(date: .long, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
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
} 