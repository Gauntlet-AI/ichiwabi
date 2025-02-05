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
                case .signedOut:
                    SignInView()
                        .environment(authService)
                case .signedIn:
                    MainAppView(authService: authService)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if authService == nil {
                authService = AuthenticationService(context: modelContext)
            }
        }
    }
}

struct MainAppView: View {
    let authService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @State private var showSignOutAlert = false
    @State private var showOnboarding = false
    @State private var userService: UserSyncService?
    @State private var storageService = StorageService()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var profilePhotoData: Data?
    @State private var showEditProfile = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        TabView {
            // Home Tab
            NavigationView {
                VStack {
                    if let user = currentUser {
                        Text("Welcome, \(user.displayName)")
                            .font(.title)
                            .padding()
                        
                        if !user.isProfileComplete {
                            Text("Please complete your profile setup")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Development section
                    Section("Development") {
                        NavigationLink("Sync Tests") {
                            SyncTestView()
                        }
                        
                        Button("Reset App State") {
                            Task {
                                do {
                                    try await resetAppState()
                                } catch {
                                    print("Error resetting app state: \(error)")
                                }
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("ichiwabi")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSignOutAlert = true }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            // Profile Tab
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        if let user = currentUser {
                            // Profile Header
                            VStack(spacing: 16) {
                                // Profile Photo
                                PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                                    if let imageData = profilePhotoData,
                                       let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                            .overlay(editPhotoOverlay)
                                    } else if let avatarURL = user.avatarURL {
                                        AsyncImage(url: avatarURL) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(editPhotoOverlay)
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 120, height: 120)
                                            .foregroundColor(.gray)
                                            .overlay(editPhotoOverlay)
                                    }
                                }
                                
                                // User Info
                                Text(user.displayName)
                                    .font(.title)
                                Text("@\(user.username)")
                                    .foregroundColor(.secondary)
                                
                                if let catchphrase = user.catchphrase {
                                    Text(catchphrase)
                                        .padding(.horizontal)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding()
                            
                            // Edit Profile Button
                            Button(action: { showEditProfile = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Profile")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // Security Settings
                            Section {
                                NavigationLink {
                                    BiometricSettingsView()
                                        .environment(authService)
                                } label: {
                                    HStack {
                                        Image(systemName: "faceid")
                                        Text("Biometric Authentication")
                                    }
                                }
                            } header: {
                                Text("Security")
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .navigationTitle("Profile")
                .sheet(isPresented: $showEditProfile) {
                    if let user = currentUser {
                        NavigationView {
                            EditProfileView(user: user)
                        }
                    }
                }
                .onChange(of: selectedProfilePhoto) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            profilePhotoData = data
                            // Upload photo to Firebase Storage
                            do {
                                isSaving = true
                                
                                // Initialize UserSyncService if needed
                                if userService == nil {
                                    userService = UserSyncService(modelContext: modelContext)
                                }
                                
                                guard let service = userService else {
                                    throw AuthError.unknown
                                }
                                
                                guard let currentUser = currentUser else {
                                    throw AuthError.notAuthenticated
                                }
                                
                                // Upload the photo
                                let downloadURL = try await storageService.uploadProfilePhoto(
                                    userId: currentUser.id,
                                    imageData: data
                                )
                                
                                // Update the user model
                                currentUser.avatarURL = downloadURL
                                currentUser.updatedAt = Date()
                                
                                // Sync with Firestore
                                try await service.sync(currentUser)
                            } catch {
                                showError = true
                                errorMessage = error.localizedDescription
                            }
                            isSaving = false
                        }
                    }
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                do {
                    try authService.signOut()
                } catch {
                    print("Error signing out: \(error)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            if let user = currentUser, !user.isProfileComplete {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            if let user = currentUser {
                OnboardingView(
                    initialUsername: user.username,
                    initialDisplayName: user.displayName
                )
            }
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