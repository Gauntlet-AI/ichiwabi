import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseStorage

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
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                HStack {
                    Button(action: moveToPreviousDay) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text(filterDate.formatted(date: .long, time: .omitted))
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    Button(action: moveToNextDay) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                if dreams.isEmpty {
                    ContentUnavailableView(
                        "No Dreams",
                        systemImage: "moon.zzz",
                        description: Text("No dreams recorded for this date")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 160), spacing: 8)
                        ], spacing: 16) {
                            ForEach(dreams) { dream in
                                DreamCell(dream: dream)
                                    .onTapGesture {
                                        print("🎯 Tap registered on DreamCell")
                                        dreamToPlay = dream
                                    }
                                    .overlay {
                                        Button {
                                            print("🎯 Button pressed on overlay")
                                            dreamToPlay = dream
                                        } label: {
                                            Color.clear
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button {
                                            print("📝 Edit button tapped for dream: \(dream.title)")
                                            dreamToEdit = dream
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        if !dream.videoURL.absoluteString.isEmpty {
                                            Button {
                                                print("▶️ Play button tapped from context menu: \(dream.title)")
                                                dreamToPlay = dream
                                            } label: {
                                                Label("Play", systemImage: "play.fill")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.darkNavy)
        }
        .onChange(of: dreamToPlay) { oldValue, newValue in
            if let dream = newValue {
                print("🔄 dreamToPlay changed to: \(dream.title)")
            } else {
                print("🔄 dreamToPlay changed to nil")
            }
        }
        .sheet(item: $dreamToEdit) { dream in
            NavigationStack {
                DreamEditView(dream: dream, modelContext: modelContext)
            }
        }
        .sheet(item: $dreamToPlay) { dream in
            NavigationStack {
                DreamPlaybackView(dream: dream, modelContext: modelContext)
            }
        }
        .background(Theme.darkNavy)
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

private struct PreviewContainer {
    static var container: ModelContainer = {
        do {
            let container = try ModelContainer(for: User.self, Dream.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = ModelContext(container)
            
            // Create a test user
            let user = User(
                id: "preview-user",
                username: "dreamwalker",
                displayName: "Dream Walker",
                email: "dream@example.com"
            )
            context.insert(user)
            
            // Create sample dreams for today
            let sampleDreams = [
                Dream(
                    userId: user.id,
                    title: "Flying Over Tokyo",
                    description: "Soaring through neon-lit skyscrapers...",
                    date: Date(),
                    videoURL: URL(string: "https://example.com/video1.mp4")!,
                    transcript: "I found myself floating above the bustling streets of Tokyo, weaving between glowing buildings that touched the clouds...",
                    dreamDate: Date()
                ),
                Dream(
                    userId: user.id,
                    title: "Underwater Library",
                    description: "Books floating in an endless ocean...",
                    date: Date(),
                    videoURL: URL(string: "")!,
                    transcript: "The library shelves stretched infinitely in every direction, books gently swaying in invisible currents while fish swam between them...",
                    dreamDate: Date()
                ),
                Dream(
                    userId: user.id,
                    title: "Time-Traveling Train",
                    description: "A mysterious journey through eras...",
                    date: Date(),
                    videoURL: URL(string: "https://example.com/video2.mp4")!,
                    transcript: "Each time the train passed through a tunnel, we emerged in a different historical period. Victorian London gave way to Ancient Egypt...",
                    dreamDate: Date()
                ),
                Dream(
                    userId: user.id,
                    title: "Garden of Memories",
                    description: "Walking through a maze of floating memories...",
                    date: Date(),
                    videoURL: URL(string: "https://example.com/video3.mp4")!,
                    transcript: "Each flower in the garden contained a different memory, blooming and releasing scenes from the past into the air like bubbles...",
                    dreamDate: Date()
                )
            ]
            
            // Insert dreams into the context
            for dream in sampleDreams {
                context.insert(dream)
            }
            
            return container
        } catch {
            fatalError("Failed to create preview container")
        }
    }()
}

#Preview {
    NavigationStack {
        LibraryView(filterDate: Date())
            .modelContainer(PreviewContainer.container)
            .preferredColorScheme(.dark)
    }
}

