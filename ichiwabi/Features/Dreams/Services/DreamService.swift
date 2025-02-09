import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
class DreamService: ObservableObject {
    private let modelContext: ModelContext
    private let userId: String
    private let calendar: Calendar
    
    @Published var dreams: [Dream] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
        
        // Use the user's current calendar with their timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
    }
    
    // MARK: - CRUD Operations
    
    func createDream(title: String, dreamDate: Date) async throws -> Dream {
        // Ensure dreamDate is normalized to start of day in user's timezone
        let normalizedDreamDate = calendar.startOfDay(for: dreamDate)
        
        let dream = Dream(
            userId: userId,
            title: title,
            description: "",
            date: Date(),
            videoURL: URL(fileURLWithPath: ""),  // Temporary URL, will be updated later
            dreamDate: normalizedDreamDate
        )
        
        modelContext.insert(dream)
        try await syncDreamToFirestore(dream)
        return dream
    }
    
    func updateDream(_ dream: Dream) async throws {
        dream.updatedAt = Date()
        try await syncDreamToFirestore(dream)
    }
    
    func deleteDream(_ dream: Dream) async throws {
        modelContext.delete(dream)
        try await deleteDreamFromFirestore(dream)
    }
    
    // MARK: - Firestore Sync
    
    private func syncDreamToFirestore(_ dream: Dream) async throws {
        print("💭 Syncing dream to Firestore - ID: \(dream.dreamId), User: \(dream.userId)")
        let docRef = Firestore.firestore().collection("dreams").document(dream.dreamId.uuidString)
        try await docRef.setData(dream.firestoreData, merge: true)
        dream.isSynced = true
        dream.lastSyncedAt = Date()
        print("💭 Dream synced successfully")
    }
    
    private func deleteDreamFromFirestore(_ dream: Dream) async throws {
        let docRef = Firestore.firestore().collection("dreams").document(dream.dreamId.uuidString)
        try await docRef.delete()
    }
    
    // MARK: - Date Operations
    
    func getDreamsForDateRange(start: Date, end: Date) async throws -> [Dream] {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        
        let query = Firestore.firestore().collection("dreams")
            .whereField("userId", isEqualTo: userId)
            .whereField("dreamDate", isGreaterThanOrEqualTo: Timestamp(date: normalizedStart))
            .whereField("dreamDate", isLessThan: Timestamp(date: normalizedEnd))
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { Dream.fromFirestore($0.data()) }
    }
    
    func getDreamsForMonth(_ date: Date) async throws -> [Dream] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            throw NSError(domain: "DreamService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date"])
        }
        
        return try await getDreamsForDateRange(start: monthStart, end: monthEnd)
    }
    
    // MARK: - Fetch Operations
    
    func fetchDreams(forDate date: Date? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var query = Firestore.firestore().collection("dreams").whereField("userId", isEqualTo: userId)
        
        if let date = date {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            query = query
                .whereField("dreamDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("dreamDate", isLessThan: Timestamp(date: endOfDay))
        }
        
        let snapshot = try await query.getDocuments()
        
        let fetchedDreams = snapshot.documents.compactMap { doc in
            Dream.fromFirestore(doc.data())
        }
        
        // Update local storage
        for dream in fetchedDreams {
            var existingDream: Dream?
            let fetchDescriptor = FetchDescriptor<Dream>(
                sortBy: [SortDescriptor(\Dream.id)]
            )
            
            // Find the dream manually since predicates are being difficult
            if let allDreams = try? modelContext.fetch(fetchDescriptor) {
                existingDream = allDreams.first { $0.id == dream.id }
            }
            
            if let existingDream = existingDream {
                // Update existing dream if remote version is newer
                if existingDream.updatedAt < dream.updatedAt {
                    existingDream.title = dream.title
                    existingDream.dreamDescription = dream.dreamDescription
                    existingDream.videoURL = dream.videoURL
                    existingDream.dreamDate = dream.dreamDate
                    existingDream.tags = dream.tags
                    existingDream.category = dream.category
                    existingDream.transcript = dream.transcript
                    existingDream.updatedAt = dream.updatedAt
                    existingDream.isSynced = true
                    existingDream.lastSyncedAt = Date()
                }
            } else {
                // Insert new dream
                dream.isSynced = true
                dream.lastSyncedAt = Date()
                modelContext.insert(dream)
            }
        }
        
        try modelContext.save()
        self.dreams = fetchedDreams
    }
    
    // MARK: - Sync Status
    
    func syncUnsyncedDreams() async throws {
        let fetchDescriptor = FetchDescriptor<Dream>(
            sortBy: [SortDescriptor(\Dream.id)]
        )
        
        // Find unsynced dreams manually
        if let allDreams = try? modelContext.fetch(fetchDescriptor) {
            let unsyncedDreams = allDreams.filter { !$0.isSynced }
            for dream in unsyncedDreams {
                try await syncDreamToFirestore(dream)
            }
        }
    }
    
    func saveDream(_ dream: Dream) async throws {
        print("💭 Saving dream to local database")
        modelContext.insert(dream)
        try modelContext.save()
        try await syncDreamToFirestore(dream)
    }
    
    func fetchDreams() throws -> [Dream] {
        let descriptor = FetchDescriptor<Dream>(
            predicate: #Predicate<Dream> { dream in
                dream.userId == userId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func deleteDream(_ dream: Dream) throws {
        modelContext.delete(dream)
        try modelContext.save()
        
        // TODO: Implement cloud sync
    }
} 
