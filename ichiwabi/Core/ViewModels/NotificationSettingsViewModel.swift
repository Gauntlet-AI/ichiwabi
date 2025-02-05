import Foundation
import SwiftUI

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var isLoading = false
    @Published var error: Error?
    
    private let notificationService = NotificationService.shared
    
    init() {
        Task {
            await loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() async {
        isEnabled = notificationService.isAuthorized
        if let currentTime = await notificationService.getCurrentMorningReminderTime() {
            reminderTime = currentTime
        }
    }
    
    func toggleNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if !notificationService.isAuthorized {
                try await notificationService.requestAuthorization()
            }
            
            if notificationService.isAuthorized {
                if isEnabled {
                    try await notificationService.scheduleMorningReminder(at: reminderTime)
                } else {
                    await notificationService.cancelMorningReminder()
                }
            }
        } catch {
            self.error = error
            isEnabled = false
        }
    }
    
    func updateReminderTime() async {
        guard isEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await notificationService.scheduleMorningReminder(at: reminderTime)
        } catch {
            self.error = error
        }
    }
} 