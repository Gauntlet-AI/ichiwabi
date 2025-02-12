import Foundation
import SwiftUI
import SwiftData

@MainActor
class HomeViewModel: ObservableObject {
    @Published var showingDreamRecorder = false
    @Published var showingAudioRecorder = false
    @Published var currentStreak = 0
    @Published var isLoading = false
    @Published var error: HomeViewError?
    
    private let modelContext: ModelContext
    private let userId: String
    private let calendar: Calendar
    private let dreamService: DreamService
    
    // Caching properties
    private var lastStreakCalculation: Date?
    private var cachedStreak: Int = 0
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
        
        // Use the user's current calendar with their timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
        
        // Initialize dream service
        self.dreamService = DreamService(modelContext: modelContext, userId: userId)
        
        Task {
            await refreshData()
        }
    }
    
    private func calculateStreakFromDreams(dreams: [Dream], today: Date) -> Int {
        // If we have a cached streak from today, use it
        if let lastCalculation = lastStreakCalculation,
           calendar.isDate(lastCalculation, inSameDayAs: today) {
            return cachedStreak
        }
        
        let normalizedToday = calendar.startOfDay(for: today)
        var streakCount = 0
        var currentDate = normalizedToday
        
        // Check if there's a dream for today (using isDate for safer comparison)
        if dreams.contains(where: { calendar.isDate($0.dreamDate, inSameDayAs: today) }) {
            streakCount += 1
        }
        
        // Check previous days
        while true {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            
            // Use isDate for safer date comparison
            if !dreams.contains(where: { calendar.isDate($0.dreamDate, inSameDayAs: previousDay) }) {
                break
            }
            
            streakCount += 1
            currentDate = previousDay
        }
        
        return streakCount
    }
    
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        let today = calendar.startOfDay(for: Date())
        
        // Load data for streak calculation
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
        
        do {
            // Single query for all needed data
            let dreams = try await dreamService.getDreamsForDateRange(
                start: thirtyDaysAgo,
                end: nextMonth
            )
            
            // Calculate streak
            let streak = calculateStreakFromDreams(dreams: dreams, today: today)
            
            // Update state
            await MainActor.run {
                self.currentStreak = streak
                self.lastStreakCalculation = today
                self.cachedStreak = streak
            }
        } catch {
            self.error = .streakCalculationFailed(error)
            currentStreak = 0
        }
    }
    
    func startRecording() {
        showingAudioRecorder = true
    }
    
    func handleRecordedAudio(_ url: URL, style: DreamVideoStyle) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create a new dream with initial state
            let dream = Dream(
                userId: userId,
                title: "Processing Dream...",  // Will be updated by API
                description: "Processing dream description...",  // Will be updated by API
                date: Date(),
                videoURL: url,  // Temporary URL, will be updated by API
                localAudioPath: url.lastPathComponent,
                videoStyle: style,
                isProcessing: true,
                processingProgress: 0
            )
            
            // Save the dream using dream service
            try await dreamService.saveDream(dream)
            
            // Refresh data to update streak
            await refreshData()
        } catch {
            throw error
        }
    }
} 