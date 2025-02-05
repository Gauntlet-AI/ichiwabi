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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Tag.self,
            Prompt.self,
            VideoResponse.self,
            Comment.self,
            Report.self,
            Notification.self,
            Dream.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: URL.documentsDirectory.appending(path: "ichiwabi.store"),
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            // If we can't open the store, try to recover by deleting it
            print("Failed to create ModelContainer: \(error)")
            
            do {
                // Delete the existing store
                try FileManager.default.removeItem(at: modelConfiguration.url)
                print("Deleted corrupted store file")
                
                // Try to create a new store
                return try ModelContainer(for: schema, configurations: modelConfiguration)
            } catch {
                fatalError("Recovery failed: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
