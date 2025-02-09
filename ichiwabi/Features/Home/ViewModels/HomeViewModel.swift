import Foundation
import SwiftUI
import SwiftData

enum HomeViewError: LocalizedError, Equatable {
    case serviceNotInitialized
    case loadFailed(Error)
    case streakCalculationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "Dream service not initialized"
        case .loadFailed(let error):
            return "Failed to load dreams: \(error.localizedDescription)"
        case .streakCalculationFailed(let error):
            return "Failed to calculate streak: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: HomeViewError, rhs: HomeViewError) -> Bool {
        switch (lhs, rhs) {
        case (.serviceNotInitialized, .serviceNotInitialized):
            return true
        case (.loadFailed, .loadFailed):
            return true
        case (.streakCalculationFailed, .streakCalculationFailed):
            return true
        default:
            return false
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentDreams: [Dream] = []
    @Published var currentStreak: Int = 0
    @Published var isLoading = false
    @Published var error: HomeViewError?
    @Published var showingDreamRecorder = false
    
    private var dreamService: DreamService?
    private let calendar = Calendar.current
    private var lastStreakCalculation: Date?
    private var cachedStreak: Int = 0
    
    init() {
        // Listen for dream updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name("DismissVideoTrimmer"),
            object: nil
        )
    }
    
    func configure(modelContext: ModelContext, userId: String) {
        self.dreamService = DreamService(modelContext: modelContext, userId: userId)
        Task {
            await loadData()
        }
    }
    
    @objc func refreshData() {
        Task {
            await loadData()
        }
    }
    
    func loadData() async {
        guard let dreamService = dreamService else {
            error = .serviceNotInitialized
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load recent dreams and calculate streak in a single operation
            let today = calendar.startOfDay(for: Date())
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            
            // Get dreams for the past 7 days plus any additional days needed for streak
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            let dreams = try await dreamService.getDreamsForDateRange(
                start: thirtyDaysAgo,
                end: today
            )
            
            // Process dreams and calculate streak
            let sortedDreams = dreams.sorted { $0.dreamDate > $1.dreamDate }
            let recentDreams = sortedDreams.filter { dream in
                dream.dreamDate >= sevenDaysAgo && dream.dreamDate <= today
            }
            
            // Calculate streak from the fetched dreams
            let streak = calculateStreakFromDreams(dreams: sortedDreams, today: today)
            
            await MainActor.run {
                self.recentDreams = recentDreams
                self.currentStreak = streak
                self.lastStreakCalculation = today
                self.cachedStreak = streak
            }
        } catch {
            self.error = .loadFailed(error)
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
    
    func startRecording() {
        showingDreamRecorder = true
    }
} 