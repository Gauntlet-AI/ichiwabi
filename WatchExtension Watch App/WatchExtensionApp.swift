//
//  WatchExtensionApp.swift
//  WatchExtension Watch App
//
//  Created by Gauntlet on 2/13/R7.
//

import SwiftUI
import FirebaseCore
import FirebaseStorage

@main
struct WatchExtensionApp: App {
    init() {
        // Initialize Firebase Auth and Storage
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Print current auth state
                    if let userId = AuthService.shared.currentUserId {
                        print("👤 Watch App User ID: \(userId)")
                    } else {
                        print("👤 Watch App: No user signed in")
                    }
                }
        }
    }
}
