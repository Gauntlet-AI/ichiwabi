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
    
    func loadDreamsForMonth(_ date: Date) async {
        let monthKey = monthKey(date)
        
        // Skip if already loaded
        guard !loadedDateRanges.contains(monthKey) else {
            return
        }
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
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
        
        var streakCount = 0
        var currentDate = today
        let dreamsGroupedByDate = Dictionary(
            grouping: dreams,
            by: { calendar.startOfDay(for: $0.dreamDate) }
        )
        
        // Check if there's a dream for today
        if dreamsGroupedByDate[today] != nil {
            streakCount += 1
        }
        
        // Check previous days
        while true {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            
            if dreamsGroupedByDate[previousDay] == nil {
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