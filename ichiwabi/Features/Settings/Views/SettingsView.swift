import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var showingEditProfile = false
    @State private var showingBiometricSettings = false
    @State private var showingNotificationSettings = false
    @State private var authService: AuthenticationService?
    
    private var currentUser: User? {
        users.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkNavy
                    .ignoresSafeArea()
                
                List {
                    // Profile Section
                    Section {
                        if let user = currentUser {
                            HStack {
                                if let avatarURL = user.avatarURL {
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
                                
                                VStack(alignment: .leading) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    showingEditProfile = true
                                } label: {
                                    Text("Edit")
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.bordered)
                                .tint(.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Profile")
                    }
                    .listRowBackground(Color.clear)
                    
                    // App Settings Section
                    Section {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("Notifications", systemImage: "bell.fill")
                        }
                        
                        if let authService = authService {
                            NavigationLink {
                                BiometricSettingsView()
                                    .environment(authService)
                            } label: {
                                Label("Security", systemImage: "lock.fill")
                            }
                        }
                    } header: {
                        Text("App Settings")
                    }
                    .listRowBackground(Color.clear)
                    
                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.appVersion)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.darkNavy)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                if let user = currentUser {
                    NavigationStack {
                        EditProfileView(user: user)
                    }
                }
            }
            .onAppear {
                if authService == nil {
                    authService = AuthenticationService(context: modelContext)
                }
            }
        }
        .background(Theme.darkNavy)
    }
}

// Helper extension to get app version
private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
