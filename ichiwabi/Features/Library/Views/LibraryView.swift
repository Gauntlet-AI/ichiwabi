import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dreams: [Dream]
    let filterDate: Date
    @State private var dreamToEdit: Dream?
    
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dreamToEdit = dream
                    }
            }
        }
        .navigationTitle(filterDate.formatted(date: .long, time: .omitted))
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
            DreamEditView(dream: dream)
        }
    }
} 