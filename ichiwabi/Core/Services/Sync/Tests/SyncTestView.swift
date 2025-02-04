import SwiftUI
import SwiftData
import FirebaseFirestore

// Import models
@preconcurrency import class ichiwabi.User
@preconcurrency import class ichiwabi.Settings
@preconcurrency import class ichiwabi.VideoResponse
@preconcurrency import class ichiwabi.Prompt
@preconcurrency import class ichiwabi.Comment

class SyncTestViewModel: ObservableObject {
    private let modelContext: ModelContext
    @Published var testResults: [String] = []
    @Published var isRunningTests = false
    private var testService: SyncTestService?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Initialize testService later in setup
        self.testService = nil
        Task {
            await setup()
        }
    }
    
    @MainActor
    private func setup() async {
        self.testService = await SyncTestService(modelContext: modelContext)
    }
    
    func runTests() {
        guard let testService = testService else { return }
        
        isRunningTests = true
        testResults.removeAll()
        
        Task {
            do {
                // Run basic sync test
                let syncResult = try await testService.testUserSync()
                await MainActor.run {
                    testResults.append(syncResult.description)
                }
                
                // Run offline test
                let offlineResult = try await testService.testOfflineSync()
                await MainActor.run {
                    testResults.append(offlineResult.description)
                }
                
                // Run conflict resolution test
                let conflictResult = try await testService.testConflictResolution()
                await MainActor.run {
                    testResults.append(conflictResult.description)
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Tests failed: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
}

struct SyncTestView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: SyncTestViewModel
    
    init(modelContext: ModelContext? = nil) {
        let schema = Schema([
            User.self,
            Settings.self,
            VideoResponse.self,
            Prompt.self,
            Comment.self
        ])
        
        let context: ModelContext
        if let providedContext = modelContext {
            context = providedContext
        } else {
            do {
                let container = try ModelContainer(for: schema)
                context = ModelContext(container)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
        
        _viewModel = StateObject(wrappedValue: SyncTestViewModel(modelContext: context))
    }
    
    var body: some View {
        List {
            Section("Test Results") {
                if viewModel.testResults.isEmpty {
                    Text("No tests run yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.testResults, id: \.self) { result in
                        Text(result)
                    }
                }
            }
            
            Section {
                Button(action: { viewModel.runTests() }) {
                    if viewModel.isRunningTests {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Run Tests")
                    }
                }
                .disabled(viewModel.isRunningTests)
            }
        }
        .navigationTitle("Sync Tests")
    }
} 