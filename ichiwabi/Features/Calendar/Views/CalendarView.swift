import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date())
    private let calendar = Calendar.current
    
    init(userId: String) {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Dream.self)
        } catch {
            fatalError("Failed to create ModelContainer for Dream: \(error)")
        }
        let dreamService = DreamService(modelContext: ModelContext(container), userId: userId)
        _viewModel = StateObject(wrappedValue: CalendarViewModel(dreamService: dreamService))
    }
    
    var body: some View {
        NavigationStack {
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
            .onChange(of: currentMonth) { oldValue, newValue in
                Task {
                    await viewModel.loadDreamsForMonth(newValue)
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
            .onAppear {
                Task {
                    await viewModel.refreshData()
                }
            }
        }
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
    
    var body: some View {
        VStack(spacing: 8) {
            // Day of week headers
            HStack {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .frame(width: daySize)
                }
            }
            
            // Days grid
            let days = calendar.daysInMonth(month)
            let firstWeekday = calendar.firstWeekday(of: month)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(daySize)), count: daysInWeek), spacing: 0) {
                ForEach(0..<firstWeekday-1, id: \.self) { _ in
                    Color.clear
                        .frame(width: daySize, height: daySize)
                }
                
                ForEach(days, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        dreamCount: getDreamCount(date)
                    )
                    .frame(width: daySize, height: daySize)
                    .onTapGesture {
                        selectedDate = date
                        viewModel.showLibraryForDate(date)
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
    
    var body: some View {
        VStack {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(.body, design: .rounded))
            
            if dreamCount > 0 {
                Text("\(dreamCount)")
                    .font(.system(.caption2, design: .rounded))
                    .padding(2)
                    .frame(minWidth: 16)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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