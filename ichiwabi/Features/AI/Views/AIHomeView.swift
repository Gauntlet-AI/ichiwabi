import SwiftUI
import SwiftData

// Move Analyst enum outside of AIHomeView
enum Analyst {
    case jung
    case freud
    
    var name: String {
        switch self {
        case .jung: return "Carl Jung"
        case .freud: return "Sigmund Freud"
        }
    }
    
    var messageColor: Color {
        switch self {
        case .jung: return Color(red: 0.3, green: 0.2, blue: 0.4) // Dark purple
        case .freud: return Color.black
        }
    }
}

struct AIHomeView: View {
    @State private var selectedAnalyst: Analyst = .jung
    @State private var isShowingDreamPicker = false
    @State private var isShowingReplacementAlert = false
    @State private var selectedDream: Dream?
    @State private var isChatMode = false
    @State private var messageText = ""
    @State private var animationPhase: Double = 0
    @State private var messages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var errorMessage: String?
    @State private var pendingAnalystChange: Analyst?
    @State private var isShowingAnalystChangeAlert = false
    
    private let dreamAnalysisService = DreamAnalysisService()
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            // Main Content (Background)
            VStack(spacing: 0) {
                if selectedDream != nil {
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(messages) { message in
                                            ChatBubbleView(message: message)
                                                .id(message.id)
                                        }
                                        if isTyping {
                                            HStack {
                                                TypingIndicatorView(analyst: selectedAnalyst)
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .id("typingIndicator")
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }
                                .safeAreaInset(edge: .top) {
                                    VStack(spacing: 0) {
                                        Color.clear
                                            .frame(height: 0)
                                            .background(Theme.darkNavy)
                                        
                                        // Height for analyst buttons + dream display
                                        Color.clear
                                            .frame(height: 160)
                                    }
                                }
                                .onChange(of: messages.count) { oldCount, newCount in
                                    withAnimation {
                                        if isTyping {
                                            proxy.scrollTo("typingIndicator", anchor: .bottom)
                                        } else if let lastId = messages.last?.id {
                                            proxy.scrollTo(lastId, anchor: .bottom)
                                        }
                                    }
                                }
                                .onChange(of: isTyping) { wasTyping, isTyping in
                                    withAnimation {
                                        if isTyping {
                                            proxy.scrollTo("typingIndicator", anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            .safeAreaInset(edge: .bottom) {
                                ChatInputView(text: $messageText, onSend: sendMessage, errorMessage: errorMessage)
                                    .transition(.move(edge: .bottom))
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // All Interactive Elements (Top layer)
            VStack {
                // Top Elements (Analyst buttons and Dream display)
                VStack {
                    // Analyst Toggle Buttons
                    HStack(spacing: 0) {
                        AnalystButton(
                            title: "Jung",
                            isSelected: selectedAnalyst == .jung,
                            action: {
                                if selectedAnalyst != .jung {
                                    pendingAnalystChange = .jung
                                    isShowingAnalystChangeAlert = true
                                }
                            }
                        )
                        Spacer()
                        AnalystButton(
                            title: "Freud",
                            isSelected: selectedAnalyst == .freud,
                            action: {
                                if selectedAnalyst != .freud {
                                    pendingAnalystChange = .freud
                                    isShowingAnalystChangeAlert = true
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .confirmationDialog(
                        "Change Analyst?",
                        isPresented: $isShowingAnalystChangeAlert,
                        titleVisibility: .visible
                    ) {
                        Button("Talk to \(pendingAnalystChange?.name ?? "")") {
                            if let analyst = pendingAnalystChange {
                                onAnalystChanged(to: analyst)
                            }
                        }
                    } message: {
                        Text("This will change the conversation. Are you sure you want to talk to \(pendingAnalystChange?.name ?? "")?")
                    }
                    
                    if let dream = selectedDream {
                        DreamDisplayView(dream: dream) {
                            isShowingReplacementAlert = true
                        }
                        .padding(.horizontal)
                        .confirmationDialog(
                            "Replace Dream?",
                            isPresented: $isShowingReplacementAlert,
                            titleVisibility: .visible
                        ) {
                            Button("Replace and Start New Chat") {
                                messages = [] // Clear messages when changing dreams
                                isShowingDreamPicker = true
                            }
                        } message: {
                            Text("Do you want to replace your dream and start a new chat?")
                        }
                    }
                }
                .background(
                    LinearGradient(
                        colors: [
                            Theme.darkNavy,
                            Theme.darkNavy,
                            Theme.darkNavy.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false) // Ensure gradient doesn't block interaction
                )
                
                Spacer()
                
                // Bottom Elements (Chat input or Plus button)
                if selectedDream != nil {
                    Spacer()
                } else {
                    HStack {
                        Spacer()
                        PlusButton {
                            haptics.impactOccurred()
                            isShowingDreamPicker = true
                        }
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $isShowingDreamPicker) {
            DreamPickerView(
                selectedDream: $selectedDream,
                isPresented: $isShowingDreamPicker,
                onDreamSelected: onDreamSelected
            )
        }
        .onAppear {
            withAnimation(
                .linear(duration: 3)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        let sentMessage = messageText
        messageText = ""
        
        // Show typing indicator
        isTyping = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await dreamAnalysisService.sendMessage(sentMessage)
                isTyping = false
                let analysisMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    analyst: selectedAnalyst
                )
                messages.append(analysisMessage)
            } catch {
                isTyping = false
                errorMessage = "Failed to connect. Please try again."
            }
        }
    }
    
    private func startNewChat(with dream: Dream) {
        Task {
            isTyping = true
            errorMessage = nil
            do {
                let response = try await dreamAnalysisService.startChat(
                    dream: dream,
                    analyst: selectedAnalyst == .jung ? "jung" : "freud"
                )
                isTyping = false
                let analysisMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    analyst: selectedAnalyst
                )
                messages = [analysisMessage]
            } catch {
                isTyping = false
                errorMessage = "Failed to connect. Please try again."
            }
        }
    }
    
    private func onDreamSelected(_ dream: Dream) {
        selectedDream = dream
        startNewChat(with: dream)
    }
    
    private func onAnalystChanged(to analyst: Analyst) {
        selectedAnalyst = analyst
        if let dream = selectedDream {
            startNewChat(with: dream)
        }
    }
}

struct DreamDisplayView: View {
    let dream: Dream
    let onTap: () -> Void
    
    @State private var gradientPosition = 0.0
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dream.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.darkNavy)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1, green: 0.92, blue: 0.6).opacity(1), // More yellow pastel
                                        Color(red: 0.4, green: 0.7, blue: 0.8).opacity(1),  // Soft blue
                                    ],
                                    startPoint: UnitPoint(x: gradientPosition, y: 0),
                                    endPoint: UnitPoint(x: gradientPosition + 1, y: 1)
                                )
                            )
                            .blendMode(.overlay)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.7)
                            ],
                            startPoint: UnitPoint(x: gradientPosition, y: 0),
                            endPoint: UnitPoint(x: gradientPosition + 0.5, y: 1)
                        ),
                        lineWidth: 1
                    )
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
            ) {
                gradientPosition = 0.5
            }
        }
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    var errorMessage: String?
    
    private let lineHeight: CGFloat = 20
    private let maxLines: CGFloat = 4
    @State private var textEditorHeight: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            HStack(alignment: .bottom) {
                TextEditor(text: $text)
                    .frame(height: textEditorHeight)
                    .scrollContentBackground(.hidden)
                    .onChange(of: text) { oldText, newText in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            let size = (newText as NSString).boundingRect(
                                with: CGSize(width: UIScreen.main.bounds.width - 100, height: .infinity),
                                options: [.usesFontLeading, .usesLineFragmentOrigin],
                                attributes: [.font: UIFont.systemFont(ofSize: 16)],
                                context: nil
                            )
                            
                            let newHeight = min(max(lineHeight, size.height + 8), lineHeight * maxLines)
                            if textEditorHeight != newHeight {
                                textEditorHeight = newHeight
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Button(action: {
                    onSend()
                    textEditorHeight = lineHeight
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .padding(.trailing)
                .disabled(text.isEmpty)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .padding(.horizontal)
    }
}

// Helper for measuring text height
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DreamPickerView: View {
    @Binding var selectedDream: Dream?
    @Binding var isPresented: Bool
    let onDreamSelected: (Dream) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var filterDate = Date()
    private let calendar = Calendar.current
    
    @Query(sort: \Dream.dreamDate, order: .reverse) private var allDreams: [Dream]
    
    private var dreams: [Dream] {
        let startOfDay = calendar.startOfDay(for: filterDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return allDreams.filter { dream in
            dream.dreamDate >= startOfDay && dream.dreamDate < endOfDay
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.darkNavy
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Date Navigation
                    HStack {
                        Button(action: moveToPreviousDay) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                        
                        Spacer()
                        
                        Text(filterDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: moveToNextDay) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    .background(Theme.darkNavy)
                    
                    if dreams.isEmpty {
                        ContentUnavailableView(
                            "No Dreams",
                            systemImage: "moon.zzz",
                            description: Text("No dreams recorded for this date")
                        )
                        .foregroundColor(.white)
                    } else {
                        List(dreams) { dream in
                            Button(action: {
                                selectedDream = dream
                                onDreamSelected(dream)
                                isPresented = false
                            }) {
                                VStack(alignment: .leading) {
                                    Text(dream.title)
                                        .font(.headline)
                                    Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .listRowBackground(Theme.darkNavy)
                        }
                        .scrollContentBackground(.hidden)
                        .background(Theme.darkNavy)
                    }
                }
            }
            .navigationTitle("Select a Dream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
        .onAppear {
            // Hide navigation bar separator
            UINavigationBar.appearance().standardAppearance.shadowColor = .clear
            UINavigationBar.appearance().scrollEdgeAppearance?.shadowColor = .clear
        }
    }
    
    private func moveToPreviousDay() {
        if let newDate = calendar.date(byAdding: .day, value: -1, to: filterDate) {
            filterDate = newDate
        }
    }
    
    private func moveToNextDay() {
        if let newDate = calendar.date(byAdding: .day, value: 1, to: filterDate) {
            filterDate = newDate
        }
    }
}

struct AnalystButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.8, blue: 0.9), // Pastel Pink
                                Color(red: 0.6, green: 0.7, blue: 1)  // Pastel Blue
                            ],
                            startPoint: UnitPoint(
                                x: cos(2 * .pi * animationPhase) * 0.5 + 0.5,
                                y: sin(2 * .pi * animationPhase) * 0.5
                            ),
                            endPoint: UnitPoint(
                                x: cos(2 * .pi * (animationPhase + 0.5)) * 0.5 + 0.5,
                                y: sin(2 * .pi * (animationPhase + 0.5)) * 0.5 + 1
                            )
                        )
                        .opacity(0.8)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 3)
                                .repeatForever(autoreverses: false)
                            ) {
                                animationPhase = 1
                            }
                        }
                    } else {
                        Color.black.opacity(0.3)
                    }
                }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(), value: isSelected)
    }
}

// Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let analyst: Analyst?
    
    init(content: String, isUser: Bool, timestamp: Date, analyst: Analyst? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.analyst = analyst
    }
}

// Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    let analyst: Analyst
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(analyst.messageColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
            if let analyst = message.analyst {
                Text(analyst.name)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, message.isUser ? 0 : 16)
            }
            
            HStack {
                if message.isUser { Spacer() }
                
                Text(message.content)
                    .font(.callout)
                    .lineSpacing(-2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser ?
                        Color(red: 0.8, green: 0.9, blue: 1.0) : // Light pastel blue
                        message.analyst?.messageColor ?? Color(UIColor.systemGray6)
                    )
                    .foregroundColor(message.isUser ? .black : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 1)
                
                if !message.isUser { Spacer() }
            }
        }
    }
}

// Add this at the end of the file, before the #Preview
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .shadow(radius: configuration.isPressed ? 2 : 10)
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Add this before the #Preview
struct PlusButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var animationPhase: Double = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                AngularGradient(
                    colors: [
                        Color(red: 1, green: 0.8, blue: 0.9), // Pastel Pink
                        Color(red: 0.6, green: 0.7, blue: 1),  // Pastel Blue
                        Color(red: 1, green: 0.8, blue: 0.9) // Back to Pink for smooth transition
                    ],
                    center: .center,
                    angle: .degrees(animationPhase * 360)
                )
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .offset(y: isPressed ? 4 : 0)
        .shadow(radius: isPressed ? 2 : 10)
        .onAppear {
            withAnimation(
                .linear(duration: 3)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    AIHomeView()
        .preferredColorScheme(.dark)
} 
