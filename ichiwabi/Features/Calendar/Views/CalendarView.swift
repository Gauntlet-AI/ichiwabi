import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date())
    private let calendar = Calendar.current
    
    private init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    static func create(userId: String, modelContext: ModelContext) -> CalendarView {
        // Use the provided ModelContext directly instead of creating a new one
        let dreamService = DreamService(modelContext: modelContext, userId: userId)
        return CalendarView(viewModel: CalendarViewModel(dreamService: dreamService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkNavy
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with streak
                    HStack {
                        Text("Dream Calendar")
                            .font(.title)
                            .bold()
                        Spacer()
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(viewModel.currentStreak) day streak")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding()
                    
                    // Month navigation
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                        
                        Spacer()
                        
                        Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Calendar content
                    MonthView(
                        month: currentMonth,
                        selectedDate: $selectedDate,
                        getDreamCount: viewModel.getDreamCount,
                        viewModel: viewModel
                    )
                    .padding(.top)
                }
                .background(Theme.darkNavy)
            }
            .onChange(of: currentMonth) { oldValue, newValue in
                // Only load if month actually changed
                if !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month) {
                    Task {
                        await viewModel.loadDreamsForMonth(newValue)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationDestination(isPresented: $viewModel.showingLibrary) {
                if let date = viewModel.selectedLibraryDate {
                    LibraryView(filterDate: date)
                }
            }
            .task {
                // Load initial data and calculate streak
                await viewModel.refreshData()
            }
        }
        .background(Theme.darkNavy)
    }
    
    private func previousMonth() {
        withAnimation {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - MonthView
private struct MonthView: View {
    let month: Date
    @Binding var selectedDate: Date
    let getDreamCount: (Date) -> Int
    @ObservedObject var viewModel: CalendarViewModel
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let daySize: CGFloat = 40
    
    private var weeks: [[Date?]] {
        let monthInterval = calendar.dateInterval(of: .month, for: month)!
        let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)!
        let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)!
        let monthWeeks = calendar.dateInterval(of: .month, for: month)!
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []
        
        // Start from the first day of the first week
        var currentDate = monthFirstWeek.start
        
        // Fill until we reach the end of the last week
        while currentDate < monthLastWeek.end {
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            
            if currentDate >= monthWeeks.start && currentDate < monthWeeks.end {
                currentWeek.append(currentDate)
            } else {
                currentWeek.append(currentDate)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Add the last week if it's not empty
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Day of week headers
            HStack {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: daySize)
                }
            }
            
            // Calendar grid
            VStack(spacing: 4) {
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let date = weeks[weekIndex][dayIndex] {
                                let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    dreamCount: getDreamCount(date),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDate = date
                                        }
                                        viewModel.showLibraryForDate(date)
                                    }
                                )
                                .frame(width: daySize, height: daySize)
                                .opacity(isCurrentMonth ? 1.0 : 0.3)
                            } else {
                                Color.clear
                                    .frame(width: daySize, height: daySize)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - DayCell
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let dreamCount: Int
    @State private var isPressed = false
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            
            // Show dot instead of number
            if dreamCount > 0 {
                Circle()
                    .fill(Color.pink.opacity(0.8))
                    .frame(width: 6, height: 6)
            } else {
                // Maintain spacing even when no dot
                Color.clear
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // Selection background
                if isSelected {
                    Color.blue.opacity(0.2)
                }
                
                // Tap feedback overlay
                Color.white
                    .opacity(isPressed ? 0.3 : 0)
            }
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(isPressed ? 0.1 : 0.2), 
               radius: isPressed ? 2 : 4, 
               x: 0, 
               y: isPressed ? 1 : 2)
        .scaleEffect(isPressed ? 0.80 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                    print("📅 Calendar day tapped: \(date)")
                    onTap()
                }
        )
    }
}

// MARK: - Calendar Extensions
private extension Calendar {
    func daysInMonth(_ date: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let monthFirstWeek = dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        let dateInterval = DateInterval(start: monthFirstWeek.start, end: monthLastWeek.end)
        return generateDates(inside: dateInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }
    
    func firstWeekday(of date: Date) -> Int {
        let components = dateComponents([.year, .month], from: date)
        guard let firstDay = self.date(from: components) else { return 1 }
        return component(.weekday, from: firstDay)
    }
    
    func generateDates(inside interval: DateInterval, matching components: DateComponents) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)
        
        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}

// MARK: - Preview
#Preview {
    do {
        // Create a test container with necessary models
        let container = try ModelContainer(
            for: User.self,
            Dream.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        
        // Create test user
        let user = User(
            id: "preview_user",
            username: "dreamwalker",
            displayName: "Dream Walker",
            email: "dream@example.com"
        )
        context.insert(user)
        
        // Create sample dreams across different dates
        let calendar = Calendar.current
        let today = Date()
        
        // Sample dates: today and several past days
        let dates: [(Date, Int)] = [
            (today, 2), // 2 dreams today
            (calendar.date(byAdding: .day, value: -1, to: today)!, 1), // 1 dream yesterday
            (calendar.date(byAdding: .day, value: -2, to: today)!, 1), // 1 dream 2 days ago
            (calendar.date(byAdding: .day, value: -4, to: today)!, 3), // 3 dreams 4 days ago
            (calendar.date(byAdding: .day, value: -7, to: today)!, 1), // 1 dream a week ago
            (calendar.date(byAdding: .day, value: -10, to: today)!, 2), // 2 dreams 10 days ago
        ]
        
        // Create dreams for each date
        for (date, count) in dates {
            for i in 0..<count {
                let dream = Dream(
                    userId: user.id,
                    title: "Dream \(i + 1) on \(date.formatted(date: .abbreviated, time: .omitted))",
                    description: "A fascinating dream about \(["flying", "exploring", "adventure", "mystery", "discovery"].randomElement()!)",
                    date: date,
                    videoURL: URL(string: "https://example.com/video\(UUID().uuidString).mp4")!,
                    transcript: "This is a sample transcript for dream \(i + 1)",
                    dreamDate: date
                )
                context.insert(dream)
            }
        }
        
        return NavigationStack {
            CalendarView.create(userId: user.id, modelContext: context)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .background(Theme.darkNavy)
                .environment(\.colorScheme, .dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.darkNavy)
    } catch {
        return Text("Failed to create preview")
            .foregroundColor(Theme.textPrimary)
    }
} 
