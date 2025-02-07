import SwiftUI
import PhotosUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @State private var userService: UserSyncService?
    @State private var storageService = StorageService()
    @State private var currentStep = 0
    @State private var username: String
    @State private var displayName: String
    @State private var catchphrase: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasAcceptedTerms = false
    @State private var isSaving = false
    
    init(initialUsername: String, initialDisplayName: String) {
        _username = State(initialValue: initialUsername)
        _displayName = State(initialValue: initialDisplayName)
    }
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: 3)
                    .padding()
                
                TabView(selection: $currentStep) {
                    // Step 1: Username and Display Name
                    VStack(spacing: 20) {
                        Text("Let's set up your profile")
                            .font(.title)
                            .multilineTextAlignment(.center)
                        
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .textContentType(.username)
                        
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.name)
                        
                        Button("Next") {
                            saveBasicInfo()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .foregroundColor(.black)
                        .disabled(username.isEmpty || displayName.isEmpty || isSaving)
                    }
                    .padding()
                    .tag(0)
                    
                    // Step 2: Profile Photo and Catchphrase
                    VStack(spacing: 20) {
                        Text("Add a photo and catchphrase")
                            .font(.title)
                            .multilineTextAlignment(.center)
                        
                        if let imageData = selectedImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Select Photo")
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        
                        TextField("Catchphrase (optional)", text: $catchphrase)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: catchphrase) { oldValue, newValue in
                                if newValue.count > 50 {
                                    catchphrase = String(newValue.prefix(50))
                                }
                            }
                        
                        Text("\(catchphrase.count)/50")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Next") {
                            savePhotoAndCatchphrase()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .foregroundColor(.black)
                        .disabled(isSaving)
                    }
                    .padding()
                    .tag(1)
                    
                    // Step 3: Terms of Service
                    VStack(spacing: 20) {
                        Text("Almost done!")
                            .font(.title)
                            .multilineTextAlignment(.center)
                        
                        ScrollView {
                            Text("""
                            Terms of Service

                            By using yorutabi, you agree to:
                            
                            1. have fun.
                            2. have a lot of fun.
                            3. have a super duper lots of fun time.
                            
                            For the complete terms, visit our website.
                            """)
                            .padding()
                        }
                        .frame(height: 200)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        Toggle("I accept the Terms of Service", isOn: $hasAcceptedTerms)
                            .padding()
                        
                        Button("Complete Setup") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .foregroundColor(.black)
                        .disabled(!hasAcceptedTerms || isSaving)
                    }
                    .padding()
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                .disabled(isSaving)
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
        .interactiveDismissDisabled()
        .onAppear {
            userService = UserSyncService(modelContext: modelContext)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
    
    private func saveBasicInfo() {
        Task {
            isSaving = true
            do {
                guard let service = userService else {
                    throw AuthError.unknown
                }
                
                guard let currentUser = currentUser else {
                    throw AuthError.notAuthenticated
                }
                
                currentUser.username = username
                currentUser.displayName = displayName
                currentUser.updatedAt = Date()
                
                try await service.sync(currentUser)
                
                withAnimation {
                    currentStep = 1
                }
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    private func savePhotoAndCatchphrase() {
        Task {
            isSaving = true
            do {
                guard let service = userService else {
                    throw AuthError.unknown
                }
                
                guard let currentUser = currentUser else {
                    throw AuthError.notAuthenticated
                }
                
                if let imageData = selectedImageData {
                    // Upload photo to Firebase Storage
                    let downloadURL = try await storageService.uploadProfilePhoto(
                        userId: currentUser.id,
                        imageData: imageData
                    )
                    
                    // Only update the URL if we successfully got one back
                    if downloadURL.absoluteString.isEmpty {
                        throw AuthError.unknown
                    }
                    currentUser.avatarURL = downloadURL
                }
                
                currentUser.catchphrase = catchphrase
                currentUser.updatedAt = Date()
                
                try await service.sync(currentUser)
                
                withAnimation {
                    currentStep = 2
                }
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    private func completeOnboarding() {
        Task {
            isSaving = true
            do {
                guard let service = userService else {
                    throw AuthError.unknown
                }
                
                guard let currentUser = currentUser else {
                    throw AuthError.notAuthenticated
                }
                
                // Mark profile as complete and terms as accepted
                currentUser.isProfileComplete = true
                currentUser.hasAcceptedTerms = hasAcceptedTerms
                currentUser.updatedAt = Date()
                
                // Sync changes to Firestore
                try await service.sync(currentUser)
                
                // Dismiss the onboarding view
                dismiss()
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    do {
        return OnboardingView(
            initialUsername: "newuser123",
            initialDisplayName: "New User"
        )
        .modelContainer(try ModelContainer(for: User.self))
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 
