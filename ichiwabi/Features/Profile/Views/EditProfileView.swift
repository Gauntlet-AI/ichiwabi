import SwiftUI
import PhotosUI
import SwiftData

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var userService: UserSyncService?
    @State private var storageService = StorageService()
    
    var body: some View {
        Form {
            Section("Profile Photo") {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        if let imageData = selectedImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else if let avatarURL = user.avatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                        }
                        
                        Text("Change Photo")
                            .foregroundColor(.black)
                    }
                }
            }
            
            Section("Profile Information") {
                TextField("Username", text: $user.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                
                TextField("Display Name", text: $user.displayName)
                    .textContentType(.name)
                
                TextField("Catchphrase (optional)", text: Binding(
                    get: { user.catchphrase ?? "" },
                    set: { user.catchphrase = $0.isEmpty ? nil : $0 }
                ))
                .onChange(of: user.catchphrase) { oldValue, newValue in
                    if let catchphrase = newValue, catchphrase.count > 50 {
                        user.catchphrase = String(catchphrase.prefix(50))
                    }
                }
                
                if let catchphrase = user.catchphrase {
                    Text("\(catchphrase.count)/50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.black)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .foregroundColor(.black)
                .disabled(isSaving)
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
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
    
    private func saveProfile() {
        Task {
            isSaving = true
            do {
                // Initialize UserSyncService if needed
                if userService == nil {
                    userService = UserSyncService(modelContext: modelContext)
                }
                
                guard let service = userService else {
                    throw AuthError.unknown
                }
                
                // Upload photo to Firebase Storage if changed
                if let imageData = selectedImageData {
                    let downloadURL = try await storageService.uploadProfilePhoto(
                        userId: user.id,
                        imageData: imageData
                    )
                    
                    // Update the avatar URL
                    user.avatarURL = downloadURL
                }
                
                // Validate username
                try user.validate()
                
                // Update timestamps
                user.updatedAt = Date()
                
                // Sync with Firestore
                try await service.sync(user)
                
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
    let config = ModelConfiguration(for: User.self)
    guard let container = try? ModelContainer(for: User.self, configurations: config) else {
        return Text("Failed to create preview container")
    }
    
    let previewUser = User(
        id: "preview_user",
        username: "johndoe",
        displayName: "John Doe",
        email: "john@example.com"
    )
    previewUser.catchphrase = "Living life one code at a time"
    container.mainContext.insert(previewUser)
    
    return NavigationView {
        EditProfileView(user: previewUser)
    }
    .modelContainer(container)
} 