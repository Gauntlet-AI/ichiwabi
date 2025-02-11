import SwiftUI
import SwiftData
import FirebaseAuth

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncViewModel: SyncViewModel
    @Query private var users: [User]
    @State private var showError = false
    @StateObject private var viewModel: HomeViewModel
    let userId: String
    @State private var showSignOutAlert = false
    @State private var error: HomeViewError?
    @State private var selectedDream: Dream?
    @State private var isPulsating = false
    @State private var isGlowing = false
    @State private var borderPhase = 0.0
    @State private var isRecordButtonPressed = false
    
    // Add haptic feedback manager
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var currentUser: User? {
        users.first
    }
    
    @MainActor
    init(userId: String, viewModel: HomeViewModel? = nil) {
        self.userId = userId
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Dream.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let context = ModelContext(container)
        
        if let existingViewModel = viewModel {
            self._viewModel = StateObject(wrappedValue: existingViewModel)
        } else {
            let newViewModel = HomeViewModel(modelContext: context, userId: userId)
            self._viewModel = StateObject(wrappedValue: newViewModel)
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarSetup()
                .toolbarSetup(syncViewModel: syncViewModel, showSignOutAlert: $showSignOutAlert)
                .alertSetup(error: $error, showError: $showError, showSignOutAlert: $showSignOutAlert, resetAppState: resetAppState)
                .fullScreenCover(isPresented: $viewModel.showingAudioRecorder) {
                    AudioRecordingView { url, style in
                        Task {
                            do {
                                try await viewModel.handleRecordedAudio(url, style: style)
                                viewModel.showingAudioRecorder = false
                            } catch {
                                self.error = .other(error.localizedDescription)
                                showError = true
                            }
                        }
                    }
                }
                .sheet(item: $selectedDream) { dream in
                    NavigationStack {
                        DreamPlaybackView(dream: dream, modelContext: modelContext)
                    }
                }
                .onChange(of: viewModel.error) { _, newError in
                    if let newError = newError {
                        error = .other(newError.localizedDescription)
                        showError = true
                    }
                }
                .onAppear {
                    // Initialize animations
                    isPulsating = true
                    isGlowing = true
                }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                if let user = currentUser {
                    welcomeSection(user: user)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                recordButton
                    .padding(.vertical, 32)
                
                Spacer()
                
                streakSection
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .padding(.vertical)
            
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }
    
    private func welcomeSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ようこそ")
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
            // Trigger haptic feedback
            hapticFeedback.impactOccurred()
            viewModel.startRecording()
        } label: {
            VStack(spacing: 16) {
                // Circle button with just the plus icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 80))
                    .frame(width: 200, height: 200)
                    .background(
                        ZStack {
                            // Base gradient layer
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 244/255, green: 218/255, blue: 248/255),
                                    Color(red: 218/255, green: 244/255, blue: 248/255),
                                    Color(red: 248/255, green: 228/255, blue: 244/255),
                                    Color(red: 244/255, green: 218/255, blue: 248/255)
                                ]),
                                center: .center,
                                angle: .degrees(isPulsating ? 360 : 0)
                            )
                            
                            // Overlay gradient for smoke effect
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.0)
                                ]),
                                center: .init(x: 0.5 + cos(isGlowing ? .pi * 2 : 0) * 0.5,
                                            y: 0.5 + sin(isGlowing ? .pi * 2 : 0) * 0.5),
                                startRadius: 0,
                                endRadius: 150
                            )
                            .blendMode(.plusLighter)
                        }
                    )
                    .foregroundColor(Theme.darkNavy)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.3),
                                        Color.blue.opacity(0.8),
                                        Color(red: 0/255, green: 122/255, blue: 255/255),
                                        Color.blue.opacity(0.8),
                                        Color.blue.opacity(0.3)
                                    ]),
                                    center: .center,
                                    angle: .degrees(borderPhase * 360)
                                ),
                                lineWidth: 5
                            )
                    )
                    .scaleEffect(isPulsating ? 1.05 : 1.0)
                    .scaleEffect(isRecordButtonPressed ? 0.92 : 1.0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.6),
                        value: isRecordButtonPressed
                    )
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isPulsating
                    )
                
                // Text below the circle
                Text("Record Dream")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(
            PressButtonStyle(
                pressAction: { isPressed in
                    isRecordButtonPressed = isPressed
                    if isPressed {
                        // Additional soft haptic for press down
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
            )
        )
        .onAppear {
            // Prepare the haptic engine
            hapticFeedback.prepare()
            
            isPulsating = true
            isGlowing = true
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                borderPhase = 1.0
            }
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
    
    private func resetAppState() async {
        do {
            // Sign out from Firebase
            try await Auth.auth().signOut()
            
            // Delete all users from modelContext
            for user in users {
                modelContext.delete(user)
            }
            try modelContext.save()
            
            // Clear UserDefaults
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        } catch {
            self.error = .signOutFailed(error.localizedDescription)
            showError = true
        }
    }
}

// MARK: - View Modifiers
private extension View {
    func navigationBarSetup() -> some View {
        self
            .navigationTitle("ｙｏｒｕｔａｂｉ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    func toolbarSetup(syncViewModel: SyncViewModel, showSignOutAlert: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await syncViewModel.syncDreams()
                        }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(syncViewModel.isSyncing)
                    
                    Button(role: .destructive) {
                        showSignOutAlert.wrappedValue = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
    
    func alertSetup(
        error: Binding<HomeViewError?>,
        showError: Binding<Bool>,
        showSignOutAlert: Binding<Bool>,
        resetAppState: @escaping () async -> Void
    ) -> some View {
        self
            .alert("Error", isPresented: showError) {
                Button("OK", role: .cancel) { 
                    error.wrappedValue = nil
                }
            } message: {
                Text(error.wrappedValue?.localizedDescription ?? "An unknown error occurred")
            }
            .alert("Sign Out", isPresented: showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await resetAppState()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? This will clear all local data.")
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
        let viewModel = HomeViewModel(modelContext: modelContext, userId: userId)
        
        // Set up preview data
        let dreams = [
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
        
        // Insert dreams into model context
        for dream in dreams {
            modelContext.insert(dream)
        }
        
        return viewModel
    }
    
    static func makePreviewContent() -> some View {
        PreviewContentView()
    }
}

// Move preview content to a separate view
private struct PreviewContentView: View {
    var body: some View {
        Group {
            if let (container, viewModel) = try? setupPreview() {
                NavigationStack {
                    HomeView(userId: "preview_user", viewModel: viewModel)
                        .modelContainer(container)
                        .environmentObject(SyncViewModel(modelContext: ModelContext(container)))
                        .preferredColorScheme(.dark)
                        .background(Theme.darkNavy)
                }
            } else {
                Text("Failed to create preview")
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
    
    private func setupPreview() throws -> (ModelContainer, HomeViewModel) {
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
        
        // Create view model using the helper function
        let viewModel = HomeView.createPreviewViewModel(modelContext: context, userId: "preview_user")
        
        return (container, viewModel)
    }
}

#Preview {
    HomeView.makePreviewContent()
}

// Add this custom button style at the bottom of the file
struct PressButtonStyle: ButtonStyle {
    let pressAction: (Bool) -> Void
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                pressAction(newValue)
            }
    }
}
