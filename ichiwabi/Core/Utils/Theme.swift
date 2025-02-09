import SwiftUI

struct Theme {
    static let darkNavy = Color(red: 0.05, green: 0.1, blue: 0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let accent = Color.pink
    
    static func applyTheme() {
        // Set UIKit elements to use our dark theme
        UITableView.appearance().backgroundColor = UIColor(Theme.darkNavy)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        
        // Set window background color
        UIWindow.appearance().backgroundColor = UIColor(Theme.darkNavy)
        
        // Set tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor(Theme.darkNavy)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.textSecondary)
        UITabBar.appearance().tintColor = UIColor(Theme.accent)
        
        // Set navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Theme.darkNavy)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
} 