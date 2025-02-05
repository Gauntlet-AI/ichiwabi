import Foundation
import UserNotifications
import SwiftUI

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published private(set) var isAuthorized = false
    @Published var lastNotificationAction: NotificationAction?
    
    private let center = UNUserNotificationCenter.current()
    private let morningNotificationId = "morning_reminder"
    
    private override init() {
        super.init()
        // Set delegate to handle notification responses
        center.delegate = self
        
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner and play sound even when app is in foreground
        return [.banner, .sound]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification tap
        if response.notification.request.identifier == morningNotificationId {
            lastNotificationAction = .recordDream
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        isAuthorized = try await center.requestAuthorization(options: options)
    }
    
    private func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Scheduling
    
    func scheduleMorningReminder(at time: Date) async throws {
        // Remove any existing morning reminder
        center.removePendingNotificationRequests(withIdentifiers: [morningNotificationId])
        
        // Create calendar components for the notification time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: time)
        components.second = 0
        
        // Create the trigger for daily notification at the specified time
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Record Your Dream"
        content.body = "Did you have any interesting dreams last night? Record them while they're still fresh in your mind."
        content.sound = .default
        content.categoryIdentifier = "dream_reminder"
        
        // Add actions for quick response
        let recordAction = UNNotificationAction(
            identifier: "record_dream",
            title: "Record Dream",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "dream_reminder",
            actions: [recordAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
        
        // Create and schedule the notification request
        let request = UNNotificationRequest(
            identifier: morningNotificationId,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
    }
    
    func cancelMorningReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [morningNotificationId])
    }
    
    func getCurrentMorningReminderTime() async -> Date? {
        let requests = await center.pendingNotificationRequests()
        guard let request = requests.first(where: { request in
            request.identifier == morningNotificationId
        }),
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        else { return nil }
        
        return Calendar.current.date(bySettingHour: trigger.dateComponents.hour ?? 0,
                                   minute: trigger.dateComponents.minute ?? 0,
                                   second: 0,
                                   of: Date())
    }
}

// MARK: - Types

extension NotificationService {
    enum NotificationAction {
        case recordDream
    }
} 