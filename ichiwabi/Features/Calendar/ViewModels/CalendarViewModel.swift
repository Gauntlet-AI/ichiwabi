import Foundation
import SwiftData

@MainActor
class CalendarViewModel: ObservableObject {
    private let dreamService: DreamService
    private let calendar = Calendar.current
    
    @Published var dreamCountByDate: [Date: Int] = [:]
    @Published var currentStreak: Int = 0
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var selectedLibraryDate: Date?
    @Published var showingLibrary: Bool = false
    
    // Caching properties
    private var lastStreakCalculation: Date?
    private var cachedStreak: Int = 0
    private var loadedDateRanges: Set<String> = []
    
    init(dreamService: DreamService) {
        self.dreamService = dreamService
    }
    
    private func monthKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
    
    func loadDreamsForMonth(_ date: Date, forceRefresh: Bool = false) async {
        let monthKey = monthKey(date)
        
        // Skip if already loaded and not forcing refresh
        guard forceRefresh || !loadedDateRanges.contains(monthKey) else {
            return
        }
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return
        }
        
        // If this is the current month, extend end date to include full current day
        let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        let monthEnd: Date
        if isCurrentMonth {
            // Use end of current day plus one day to ensure we catch all dreams
            monthEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        } else {
            // Use end of last day of month
            monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: 0), to: monthStart)!
        }
        
        do {
            let dreams = try await dreamService.getDreamsForDateRange(start: monthStart, end: monthEnd)
            
            // Group dreams by date
            var countByDate: [Date: Int] = [:]
            for dream in dreams {
                let normalizedDate = calendar.startOfDay(for: dream.dreamDate)
                countByDate[normalizedDate, default: 0] += 1
            }
            
            // Update the published property on the main thread
            await MainActor.run {
                // If forcing refresh, remove old data for this month
                if forceRefresh {
                    // Remove existing entries for this month
                    let monthStartDate = calendar.startOfDay(for: monthStart)
                    let monthEndDate = calendar.startOfDay(for: monthEnd)
                    dreamCountByDate = dreamCountByDate.filter { date, _ in
                        !calendar.isDate(date, equalTo: monthStartDate, toGranularity: .month)
                    }
                }
                
                dreamCountByDate.merge(countByDate) { _, new in new }
                loadedDateRanges.insert(monthKey)
            }
        } catch {
            self.error = error
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
        
        // Group dreams by normalized date
        let dreamsGroupedByDate = Dictionary(
            grouping: dreams,
            by: { calendar.startOfDay(for: $0.dreamDate) }
        )
        
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
    
    func getDreamCount(for date: Date) -> Int {
        let normalizedDate = calendar.startOfDay(for: date)
        return dreamCountByDate[normalizedDate] ?? 0
    }
    
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Clear all caches
        loadedDateRanges.removeAll()
        lastStreakCalculation = nil
        cachedStreak = 0
        
        let today = calendar.startOfDay(for: Date())
        
        // Load data for streak calculation and current view
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
            
            // Group dreams by date for the calendar view
            var countByDate: [Date: Int] = [:]
            for dream in dreams {
                let normalizedDate = calendar.startOfDay(for: dream.dreamDate)
                countByDate[normalizedDate, default: 0] += 1
            }
            
            // Update all state at once
            await MainActor.run {
                self.dreamCountByDate = countByDate
                self.currentStreak = streak
                self.lastStreakCalculation = today
                self.cachedStreak = streak
                
                // Mark relevant months as loaded
                var currentDate = thirtyDaysAgo
                while currentDate <= nextMonth {
                    loadedDateRanges.insert(monthKey(currentDate))
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? nextMonth
                }
            }
        } catch {
            self.error = error
        }
    }
    
    func showLibraryForDate(_ date: Date) {
        selectedLibraryDate = calendar.startOfDay(for: date)
        showingLibrary = true
    }
} 