//
//  ichiwabiApp.swift
//  ichiwabi
//
//  Created by Gauntlet on 2/3/R7.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct IchiwabiApp: App {
    init() {
        // Configure Firebase
        FirebaseConfig.configure()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Prompt.self,
            VideoResponse.self,
            Comment.self,
            Notification.self,
            Settings.self,
            Report.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
