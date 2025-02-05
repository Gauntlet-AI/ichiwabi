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
    
    init() {}
    
    func configure(modelContext: ModelContext, userId: String) {
        self.dreamService = DreamService(modelContext: modelContext, userId: userId)
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
            // Load recent dreams (last 7 days)
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            
            let dreams = try await dreamService.getDreamsForDateRange(
                start: startDate,
                end: endDate
            )
            
            await MainActor.run {
                self.recentDreams = dreams.sorted { $0.dreamDate > $1.dreamDate }
            }
            
            // Calculate current streak
            await calculateStreak()
        } catch {
            self.error = .loadFailed(error)
        }
    }
    
    private func calculateStreak() async {
        guard let dreamService = dreamService else {
            error = .serviceNotInitialized
            return
        }
        
        let today = calendar.startOfDay(for: Date())
        var currentDate = today
        var streakCount = 0
        
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
                self.error = .streakCalculationFailed(error)
                break
            }
        }
        
        await MainActor.run {
            self.currentStreak = streakCount
        }
    }
    
    func startRecording() {
        showingDreamRecorder = true
    }
} 