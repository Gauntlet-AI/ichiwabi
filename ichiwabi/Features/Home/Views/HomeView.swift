import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var showError = false
    @StateObject private var viewModel = HomeViewModel()
    let userId: String
    
    private var currentUser: User? {
        users.first
    }
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        mainContent
            .navigationTitle("ichiwabi")
            .overlay(loadingOverlay)
            .onChange(of: viewModel.error, initial: false) { _, _ in
                showError = viewModel.error != nil
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .fullScreenCover(isPresented: $viewModel.showingDreamRecorder) {
                if let user = currentUser {
                    NavigationStack {
                        DreamRecorderView(userId: user.id)
                    }
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext, userId: userId)
            }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Section
                if let user = currentUser {
                    welcomeSection(user: user)
                }
                
                // Quick Record Button
                recordButton
                
                // Streak Section
                streakSection
                
                // Recent Dreams Section
                recentDreamsSection
            }
            .padding()
        }
    }
    
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private func welcomeSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(user.displayName)
                .font(.title)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recordButton: some View {
        Button {
            viewModel.startRecording()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Record Dream")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var streakSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.currentStreak) Day Streak")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                NavigationLink {
                    CalendarView(userId: currentUser?.id ?? "")
                } label: {
                    Text("View Calendar")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            }
            
            // Streak visualization
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.currentStreak ? Color.orange : Color.gray.opacity(0.3))
                        .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentDreamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Dreams")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                NavigationLink {
                    LibraryView(filterDate: Date())
                } label: {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            }
            
            if viewModel.recentDreams.isEmpty {
                ContentUnavailableView(
                    "No Recent Dreams",
                    systemImage: "moon.zzz",
                    description: Text("Dreams you record will appear here")
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.recentDreams) { dream in
                        DreamCell(dream: dream)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
} 
