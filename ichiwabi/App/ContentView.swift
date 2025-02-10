import SwiftUI
import PhotosUI
import SwiftData
import FirebaseStorage

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @State private var authService: AuthenticationService?
    @State private var userService: UserSyncService?
    @State private var storageService = StorageService()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var profilePhotoData: Data?
    @State private var showEditProfile = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showSignOutAlert = false
    @State private var showOnboarding = false
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            Group {
                if let authService = authService {
                    switch authService.authState {
                    case .loading:
                        ProgressView()
                            .tint(Theme.textPrimary)
                            .onAppear {
                                print("🔄 ContentView: Showing loading state")
                            }
                    case .signedOut:
                        SignInView()
                            .environment(authService)
                            .onAppear {
                                print("👤 ContentView: Showing sign in view")
                            }
                    case .signedIn:
                        if let user = currentUser {
                            if user.isProfileComplete {
                                MainAppView(authService: authService)
                                    .onAppear {
                                        print("✅ ContentView: Showing main app view for completed profile")
                                    }
                            } else {
                                OnboardingView(
                                    initialUsername: user.username,
                                    initialDisplayName: user.displayName
                                )
                                .onAppear {
                                    print("📝 ContentView: Showing onboarding view for incomplete profile")
                                }
                            }
                        } else {
                            ProgressView()
                                .tint(Theme.textPrimary)
                                .onAppear {
                                    print("⚠️ ContentView: User is signed in but no user data found")
                                }
                        }
                    }
                } else {
                    ProgressView()
                        .tint(Theme.textPrimary)
                        .onAppear {
                            print("⏳ ContentView: Initial loading state - no auth service")
                        }
                }
            }
        }
        .onAppear {
            print("🚀 ContentView: View appeared")
            if authService == nil {
                print("🔐 ContentView: Creating new AuthenticationService")
                authService = AuthenticationService(context: modelContext)
            }
            Theme.applyTheme()
        }
        .foregroundColor(Theme.textPrimary)
    }
}

struct MainAppView: View {
    let authService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @State private var showSignOutAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var selectedTab = 0
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                ZStack {
                    Theme.darkNavy
                        .ignoresSafeArea()
                    
                    HomeView(userId: currentUser?.id ?? "")
                }
            }
            .tabItem {
                Label("Home", systemImage: "plus.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 131/255, green: 125/255, blue: 242/255), Color(red: 255/255, green: 204/255, blue: 255/255))

            }
            .tag(0)
            
            // Calendar Tab
            NavigationStack {
                if let userId = currentUser?.id {
                    CalendarView.create(userId: userId, modelContext: modelContext)
                }
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 255/255, green: 204/255, blue: 255/255), Color(red: 131/255, green: 125/255, blue: 242/255))

            }
            .tag(1)
            
            // AI Tab
            NavigationStack {
                AIHomeView()
            }
            .tabItem {
                Image(systemName: "star.bubble")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 131/255, green: 125/255, blue: 242/255), Color(red: 255/255, green: 204/255, blue: 255/255))
                Text("Jung")
            }
            .tag(2)
            
            // Library Tab
            NavigationStack {
                LibraryView(filterDate: Date())
            }
            .tabItem {
                Label("Dreams", systemImage: "smoke")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 255/255, green: 204/255, blue: 255/255), Color(red: 131/255, green: 125/255, blue: 242/255))

            }
            .tag(3)
            
            // Profile Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 255/255, green: 204/255, blue: 255/255), Color(red: 131/255, green: 125/255, blue: 242/255))

            }
            .tag(4)
        }
        .background(Theme.darkNavy)
        .tint(Color.pink)
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        try await resetAppState()
                    } catch {
                        showError = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isSaving {
                ProgressView()
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private func resetAppState() async throws {
        // Sign out
        try authService.signOut()
        
        // Clear SwiftData
        for user in users {
            modelContext.delete(user)
        }
        try modelContext.save()
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

private var editPhotoOverlay: some View {
    ZStack {
        Color.black.opacity(0.1)
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
}

#Preview {
    ContentView()
} 
