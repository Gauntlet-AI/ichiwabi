import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncViewModel: SyncViewModel
    @Query private var users: [User]
    @State private var showError = false
    @StateObject private var viewModel: HomeViewModel
    let userId: String
    
    private var currentUser: User? {
        users.first
    }
    
    @MainActor
    init(userId: String, viewModel: HomeViewModel? = nil) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
    }
    
    var body: some View {
        mainContent
            .navigationTitle("yorutabi")
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
                .foregroundStyle(Theme.textSecondary)
            Text(user.displayName)
                .font(.title)
                .bold()
                .foregroundColor(Theme.textPrimary)
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
            .foregroundColor(Theme.darkNavy)
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
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                NavigationLink {
                    LibraryView(filterDate: Date())
                } label: {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }
            }
            
            if viewModel.recentDreams.isEmpty {
                ContentUnavailableView(
                    "No Recent Dreams",
                    systemImage: "moon.zzz",
                    description: Text("Dreams you record will appear here")
                )
                .foregroundColor(Theme.textPrimary)
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
    struct PreviewWrapper: View {
        let content: AnyView
        
        var body: some View {
            NavigationStack {
                content
                    .preferredColorScheme(.dark)
                    .background(Theme.darkNavy)
            }
        }
    }
    
    @MainActor
    static func createPreviewViewModel(modelContext: ModelContext, userId: String) -> HomeViewModel {
        let viewModel = HomeViewModel()
        viewModel.configure(modelContext: modelContext, userId: userId)
        
        // Set up preview data
        viewModel.recentDreams = [
            Dream(
                userId: userId,
                title: "Flying Over Mountains",
                description: "I was soaring over snow-capped peaks, feeling the crisp wind against my face...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video1.mp4")!,
                transcript: "I was soaring over snow-capped peaks, feeling the crisp wind against my face. The air was cold but exhilarating, and I could see for miles in every direction.",
                dreamDate: Date()
            ),
            Dream(
                userId: userId,
                title: "Underwater City",
                description: "Discovered a magnificent city beneath the waves, with buildings made of coral...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video2.mp4")!,
                transcript: "Discovered a magnificent city beneath the waves, with buildings made of coral and streets paved with pearls. Sea creatures swam through windows like birds.",
                dreamDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
            Dream(
                userId: userId,
                title: "Time Travel to Ancient Egypt",
                description: "Walking among the pyramids as they were being built...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video3.mp4")!,
                transcript: "I found myself in ancient Egypt, watching thousands of workers building the great pyramids. The limestone blocks gleamed white in the desert sun.",
                dreamDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            )
        ]
        viewModel.currentStreak = 3
        return viewModel
    }
    
    @MainActor
    static func makePreview() -> some View {
        // Create a simple user for the preview
        let user = User(
            id: "preview_user",
            username: "dreamwalker",
            displayName: "Dream Walker",
            email: "dream@example.com"
        )
        
        // Create minimal container just for the user
        do {
            let container = try ModelContainer(for: User.self, Dream.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = ModelContext(container)
            context.insert(user)
            
            // Create and configure the preview view model
            let viewModel = createPreviewViewModel(modelContext: context, userId: "preview_user")
            
            return PreviewWrapper(content: AnyView(
                HomeView(userId: "preview_user", viewModel: viewModel)
                    .modelContainer(container)
                    .environmentObject(SyncViewModel(modelContext: context))
            ))
        } catch {
            return PreviewWrapper(content: AnyView(
                Text("Preview creation failed")
                    .foregroundColor(Theme.textPrimary)
            ))
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(for: User.self, Dream.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        
        // Create and insert user
        let user = User(
            id: "preview_user",
            username: "dreamwalker",
            displayName: "Dream Walker",
            email: "dream@example.com"
        )
        context.insert(user)
        
        // Create view model with sample data
        let viewModel = HomeViewModel()
        viewModel.recentDreams = [
            Dream(
                userId: "preview_user",
                title: "Flying Over Mountains",
                description: "I was soaring over snow-capped peaks...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video1.mp4")!,
                transcript: "I was soaring over snow-capped peaks, feeling the crisp wind against my face.",
                dreamDate: Date()
            ),
            Dream(
                userId: "preview_user",
                title: "Underwater City",
                description: "Discovered a magnificent city beneath the waves...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video2.mp4")!,
                transcript: "Discovered a magnificent city beneath the waves, with buildings made of coral.",
                dreamDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
            Dream(
                userId: "preview_user",
                title: "Time Travel to Ancient Egypt",
                description: "Walking among the pyramids...",
                date: Date(),
                videoURL: URL(string: "https://example.com/video3.mp4")!,
                transcript: "I found myself in ancient Egypt, watching the pyramids being built.",
                dreamDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            )
        ]
        viewModel.currentStreak = 3
        
        return NavigationStack {
            HomeView(userId: "preview_user", viewModel: viewModel)
                .modelContainer(container)
                .environmentObject(SyncViewModel(modelContext: context))
                .preferredColorScheme(.dark)
                .background(Theme.darkNavy)
        }
    } catch {
        return Text("Failed to create preview")
            .foregroundColor(Theme.textPrimary)
    }
} 
