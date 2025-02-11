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
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
        
        // Use the user's current calendar with their timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
        
        Task {
            await calculateStreak()
        }
    }
    
    private func calculateStreak() async {
        let fetchDescriptor = FetchDescriptor<Dream>(
            sortBy: [SortDescriptor(\Dream.dreamDate, order: .reverse)]
        )
        
        do {
            let dreams = try modelContext.fetch(fetchDescriptor)
            
            let today = calendar.startOfDay(for: Date())
            var streakCount = 0
            var currentDate = today
            
            for dream in dreams {
                let dreamDate = calendar.startOfDay(for: dream.dreamDate)
                
                // If we've missed a day, break the streak
                if let daysBetween = calendar.dateComponents([.day], from: dreamDate, to: currentDate).day,
                   daysBetween > 1 {
                    break
                }
                
                // If this dream is from the same day we already counted, skip it
                if dreamDate == currentDate {
                    continue
                }
                
                // If this dream is from the previous day, increment streak and move to that day
                if let daysBetween = calendar.dateComponents([.day], from: dreamDate, to: currentDate).day,
                   daysBetween == 1 {
                    streakCount += 1
                    currentDate = dreamDate
                }
            }
            
            // Check if we have a dream for today
            if dreams.contains(where: { calendar.startOfDay(for: $0.dreamDate) == today }) {
                streakCount += 1
            }
            
            currentStreak = streakCount
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
            
            // Save the dream to local storage
            modelContext.insert(dream)
            try modelContext.save()
        } catch {
            self.error = .other("Failed to save dream: \(error.localizedDescription)")
            throw error
        }
    }
} 