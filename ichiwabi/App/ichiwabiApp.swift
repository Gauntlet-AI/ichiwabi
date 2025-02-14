//
//  ichiwabiApp.swift
//  ichiwabi
//
//  Created by Gauntlet on 2/3/R7.
//

import SwiftUI
import SwiftData
import FirebaseCore
import UIKit
import FirebaseAuth
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Apply theme at launch
        Theme.applyTheme()
        
        // Configure background tasks
        BGTaskScheduler.shared.setAuthorizationHandler { granted in
            if granted {
                print("✅ Background task authorization granted")
            } else {
                print("❌ Background task authorization denied")
            }
        }
        
        // Request notification authorization on first launch
        Task {
            do {
                try await NotificationService.shared.requestAuthorization()
            } catch {
                print("Failed to request notification authorization: \(error)")
            }
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Sign out when app enters background
        try? Auth.auth().signOut()
        
        // Clear any stored credentials
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Configure window appearance after launch
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = .dark
                window.backgroundColor = UIColor(Theme.darkNavy)
            }
        }
    }
    
    // Handle remote notification registration
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Store device token for future use with FCM
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

@main
struct IchiwabiApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var watchSyncManager = WatchSyncManager.shared
    @State private var showingRecorder = false
    @State private var syncViewModel: SyncViewModel?
    
    var sharedModelContainer: ModelContainer = {
        print("\n📱 ==================== APP INIT ====================")
        print("📱 Creating shared ModelContainer...")
        
        // Define the schema models
        let models: [any PersistentModel.Type] = [
            User.self,
            Tag.self,
            Prompt.self,
            VideoResponse.self,
            Comment.self,
            Report.self,
            Notification.self,
            Dream.self
        ]
        
        // Create the schema
        let schema = Schema(models)
        print("📱 Schema created with models: User, Tag, Prompt, VideoResponse, Comment, Report, Notification, Dream")
        
        // Define the store URL
        let storeURL = URL.documentsDirectory.appending(path: "ichiwabi.store")
        
        // Create the configuration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
        print("📱 Model configuration created at: \(storeURL.path)")
        
        do {
            let container = try ModelContainer(for: schema, configurations: modelConfiguration)
            print("✅ ModelContainer created successfully")
            print("📱 ==================== APP INIT END ====================\n")
            return container
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            
            do {
                // Delete the existing store
                try FileManager.default.removeItem(at: modelConfiguration.url)
                print("🗑️ Deleted corrupted store file")
                
                // Clean up any Core Data SQLite files
                let sqliteStoreURL = URL.documentsDirectory.appending(path: "default.store")
                let sqliteFiles = [
                    sqliteStoreURL,
                    sqliteStoreURL.appendingPathExtension("sqlite"),
                    sqliteStoreURL.appendingPathExtension("sqlite-shm"),
                    sqliteStoreURL.appendingPathExtension("sqlite-wal")
                ]
                
                for url in sqliteFiles {
                    try? FileManager.default.removeItem(at: url)
                    print("🗑️ Attempted to delete Core Data file: \(url.lastPathComponent)")
                }
                
                // Create a new container
                let newContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
                print("✅ Recovery successful - new ModelContainer created")
                print("📱 ==================== APP INIT END ====================\n")
                return newContainer
            } catch {
                print("❌ Recovery failed: \(error)")
                print("📱 ==================== APP INIT END ====================\n")
                fatalError("Recovery failed: \(error)")
            }
        }
    }()
    
    // Helper view to handle notifications and recording
    private struct MainContentView: View {
        @ObservedObject var notificationService: NotificationService
        @ObservedObject var watchSyncManager: WatchSyncManager
        @Binding var showingRecorder: Bool
        let syncViewModel: SyncViewModel
        
        var body: some View {
            ZStack {
                Theme.darkNavy
                    .ignoresSafeArea()
                
                ContentView()
                    .onChange(of: notificationService.lastNotificationAction) { oldValue, newValue in
                        if newValue == .recordDream {
                            showingRecorder = true
                            notificationService.lastNotificationAction = nil
                        }
                    }
                    .fullScreenCover(isPresented: $showingRecorder) {
                        if let userId = Auth.auth().currentUser?.uid {
                            DreamRecorderView(userId: userId)
                        }
                    }
            }
            .environmentObject(syncViewModel)
            .environmentObject(watchSyncManager)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.darkNavy
                    .ignoresSafeArea()
                
                Group {
                    if let syncViewModel = syncViewModel {
                        MainContentView(
                            notificationService: notificationService,
                            watchSyncManager: watchSyncManager,
                            showingRecorder: $showingRecorder,
                            syncViewModel: syncViewModel
                        )
                    } else {
                        ProgressView()
                    }
                }
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(.dark)
                .tint(Color.pink)
            }
            .task {
                await initializeAndSync()
            }
            .onChange(of: Auth.auth().currentUser) { oldValue, newValue in
                if newValue != nil {
                    Task {
                        await syncViewModel?.syncDreams()
                    }
                }
            }
        }
    }
    
    // Helper function to initialize and sync
    private func initializeAndSync() async {
        if syncViewModel == nil {
            syncViewModel = SyncViewModel(modelContext: sharedModelContainer.mainContext)
        }
        if Auth.auth().currentUser != nil {
            await syncViewModel?.syncDreams()
        }
    }
}
