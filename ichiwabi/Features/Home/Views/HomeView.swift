import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncViewModel: SyncViewModel
    @Query private var users: [User]
    @State private var showError = false
    @StateObject private var viewModel = HomeViewModel()
    let userId: String
    
    private var currentUser: User? {
        users.first
    }
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        mainContent
            .navigationTitle("ichiwabi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await syncViewModel.syncDreams()
                        }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(syncViewModel.isSyncing)
                }
            }
            .overlay(loadingOverlay)
            .onChange(of: viewModel.error, initial: false) { _, _ in
                showError = viewModel.error != nil
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .fullScreenCover(isPresented: $viewModel.showingDreamRecorder) {
                if let user = currentUser {
                    NavigationStack {
                        DreamRecorderView(userId: user.id)
                    }
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext, userId: userId)
            }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Section
                if let user = currentUser {
                    welcomeSection(user: user)
                }
                
                // Quick Record Button
                recordButton
                
                // Streak Section
                streakSection
                
                // Recent Dreams Section
                recentDreamsSection
            }
            .padding()
        }
    }
    
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading || syncViewModel.isSyncing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private func welcomeSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(user.displayName)
                .font(.title)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recordButton: some View {
        Button {
            viewModel.startRecording()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Record Dream")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var streakSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.currentStreak) Day Streak")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                NavigationLink {
                    CalendarView.create(userId: currentUser?.id ?? "", modelContext: modelContext)
                } label: {
                    Text("View Calendar")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            
            // Streak visualization
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.currentStreak ? Color.yellow : Color.gray.opacity(0.3))
                        .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentDreamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Dreams")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                NavigationLink {
                    LibraryView(filterDate: Date())
                } label: {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            }
            
            if viewModel.recentDreams.isEmpty {
                ContentUnavailableView(
                    "No Recent Dreams",
                    systemImage: "moon.zzz",
                    description: Text("Dreams you record will appear here")
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.recentDreams) { dream in
                        DreamCell(dream: dream)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

private extension HomeView {
    static func makePreview() -> AnyView {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: User.self, Dream.self, configurations: config)
            
            // Create sample user
            let user = User(
                id: "preview_user",
                username: "dreamwalker",
                displayName: "Dream Walker",
                email: "dream@example.com"
            )
            
            // Create sample dreams
            let dreams = [
                Dream(
                    userId: user.id,
                    title: "Flying Over Mountains",
                    description: "I was soaring over snow-capped peaks, feeling the crisp wind against my face...",
                    date: Date(),
                    videoURL: URL(string: "https://example.com/video1.mp4")!,
                    transcript: "I was soaring over snow-capped peaks, feeling the crisp wind against my face...",
                    dreamDate: Date()
                ),
                Dream(
                    userId: user.id,
                    title: "Underwater City",
                    description: "Discovered a magnificent city beneath the waves, with buildings made of coral...",
                    date: Date(),
                    videoURL: URL(string: "https://example.com/video2.mp4")!,
                    transcript: "Discovered a magnificent city beneath the waves, with buildings made of coral...",
                    dreamDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                )
            ]
            
            // Add to container
            container.mainContext.insert(user)
            dreams.forEach { container.mainContext.insert($0) }
            
            return AnyView(
                HomeView(userId: user.id)
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
                    .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            )
        } catch {
            return AnyView(
                Text("Failed to create preview: \(error.localizedDescription)")
            )
        }
    }
}

#Preview {
    HomeView.makePreview()
} 
