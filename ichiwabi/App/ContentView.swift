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
        Group {
            if let authService = authService {
                switch authService.authState {
                case .loading:
                    ProgressView()
                        .tint(Theme.textPrimary)
                case .signedOut:
                    SignInView()
                        .environment(authService)
                case .signedIn:
                    if let user = currentUser {
                        if user.isProfileComplete {
                            MainAppView(authService: authService)
                        } else {
                            OnboardingView(
                                initialUsername: user.username,
                                initialDisplayName: user.displayName
                            )
                        }
                    } else {
                        ProgressView()
                            .tint(Theme.textPrimary)
                            .onAppear {
                                print("⚠️ User is signed in but no user data found")
                            }
                    }
                }
            } else {
                ProgressView()
                    .tint(Theme.textPrimary)
            }
        }
        .onAppear {
            if authService == nil {
                authService = AuthenticationService(context: modelContext)
            }
            Theme.applyTheme()
        }
        .background(Theme.darkNavy)
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
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        TabView {
            // Home Tab
            NavigationStack {
                HomeView(userId: currentUser?.id ?? "")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            // Calendar Tab
            NavigationStack {
                if let userId = currentUser?.id {
                    CalendarView.create(userId: userId, modelContext: modelContext)
                }
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            
            // Library Tab
            NavigationStack {
                LibraryView(filterDate: Date())
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            
            // Profile Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
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