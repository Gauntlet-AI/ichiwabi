import SwiftUI

struct Theme {
    static let darkNavy = Color(red: 0.05, green: 0.1, blue: 0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let accent = Color.white
    
    static func applyTheme() {
        // Set UIKit elements to use our dark theme
        UITableView.appearance().backgroundColor = UIColor(Theme.darkNavy)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
    }
} 