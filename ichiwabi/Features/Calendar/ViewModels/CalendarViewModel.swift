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
    
    init(dreamService: DreamService) {
        self.dreamService = dreamService
    }
    
    func loadDreamsForMonth(_ date: Date) async {
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
            }
        } catch {
            self.error = error
        }
    }
    
    func calculateStreak() async {
        let today = calendar.startOfDay(for: Date())
        var currentDate = calendar.date(byAdding: .day, value: -1, to: today)! // Start from yesterday
        var streakCount = 0
        
        // First check if there's a dream for today
        let todayDreams = try? await dreamService.getDreamsForDateRange(
            start: today,
            end: today
        )
        
        if let todayDreams = todayDreams, !todayDreams.isEmpty {
            streakCount += 1
        }
        
        // Then check previous days
        while true {
            do {
                let dreams = try await dreamService.getDreamsForDateRange(
                    start: currentDate,
                    end: currentDate
                )
                
                if dreams.isEmpty {
                    break
                }
                
                streakCount += 1
                
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } catch {
                self.error = error
                break
            }
        }
        
        await MainActor.run {
            self.currentStreak = streakCount
        }
    }
    
    func getDreamCount(for date: Date) -> Int {
        let normalizedDate = calendar.startOfDay(for: date)
        return dreamCountByDate[normalizedDate] ?? 0
    }
    
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load current month and adjacent months
        let current = Date()
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: current),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: current) {
            await loadDreamsForMonth(previousMonth)
            await loadDreamsForMonth(current)
            await loadDreamsForMonth(nextMonth)
        }
        
        await calculateStreak()
    }
    
    func showLibraryForDate(_ date: Date) {
        selectedLibraryDate = calendar.startOfDay(for: date)
        showingLibrary = true
    }
} 