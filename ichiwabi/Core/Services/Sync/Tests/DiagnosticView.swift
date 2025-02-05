import SwiftUI
import SwiftData
import FirebaseFirestore

struct DiagnosticView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunningTests = false
    
    struct DiagnosticResult: Identifiable {
        let id = UUID()
        let title: String
        let status: Status
        let message: String
        let timestamp: Date
        
        enum Status {
            case success
            case failure
            case info
            
            var color: Color {
                switch self {
                case .success: return .green
                case .failure: return .red
                case .info: return .blue
                }
            }
        }
    }
    
    var body: some View {
        List {
            Section("Diagnostic Controls") {
                Button(action: runAllTests) {
                    if isRunningTests {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Run All Tests")
                    }
                }
                .disabled(isRunningTests)
                
                Button("Clear Results") {
                    diagnosticResults.removeAll()
                }
                .disabled(isRunningTests)
            }
            
            Section("Test Results") {
                if diagnosticResults.isEmpty {
                    Text("No tests run yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(diagnosticResults) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.title)
                                    .font(.headline)
                                Spacer()
                                Text(result.timestamp.formatted(.dateTime.hour().minute().second()))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(result.message)
                                .font(.subheadline)
                                .foregroundColor(result.status.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
    }
    
    private func runAllTests() {
        guard !isRunningTests else { return }
        isRunningTests = true
        diagnosticResults.removeAll()
        
        Task {
            // Test 1: Model Container Configuration
            await testModelContainer()
            
            // Test 2: Model Context Access
            await testModelContext()
            
            // Test 3: Basic Model Creation
            await testModelCreation()
            
            // Test 4: Model Relationships
            await testModelRelationships()
            
            // Test 5: Firebase Connection
            await testFirebaseConnection()
            
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    @MainActor
    private func addResult(_ title: String, status: DiagnosticResult.Status, message: String) {
        let result = DiagnosticResult(
            title: title,
            status: status,
            message: message,
            timestamp: Date()
        )
        diagnosticResults.insert(result, at: 0)
    }
    
    private func testModelContainer() async {
        await MainActor.run {
            do {
                let container = try ModelContainer(for: Schema([
                    User.self,
                    Settings.self,
                    VideoResponse.self,
                    Prompt.self,
                    Comment.self,
                    Notification.self,
                    Report.self,
                    Tag.self
                ]))
                addResult(
                    "Model Container Test",
                    status: .success,
                    message: "Successfully created model container with all models"
                )
            } catch {
                addResult(
                    "Model Container Test",
                    status: .failure,
                    message: "Failed to create model container: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func testModelContext() async {
        await MainActor.run {
            if modelContext != nil {
                addResult(
                    "Model Context Test",
                    status: .success,
                    message: "Successfully accessed model context"
                )
            } else {
                addResult(
                    "Model Context Test",
                    status: .failure,
                    message: "Failed to access model context"
                )
            }
        }
    }
    
    private func testModelCreation() async {
        await MainActor.run {
            do {
                // Try to create and save a test user
                let testUser = User(
                    id: "test_\(UUID().uuidString)",
                    username: "testuser",
                    displayName: "Test User",
                    email: "test@example.com"
                )
                modelContext.insert(testUser)
                try modelContext.save()
                
                // Try to fetch the user back
                let descriptor = FetchDescriptor<User>(
                    predicate: #Predicate<User> { user in
                        user.username == "testuser"
                    }
                )
                let users = try modelContext.fetch(descriptor)
                
                if users.count > 0 {
                    addResult(
                        "Model Creation Test",
                        status: .success,
                        message: "Successfully created and retrieved test user"
                    )
                } else {
                    addResult(
                        "Model Creation Test",
                        status: .failure,
                        message: "Created user but failed to retrieve it"
                    )
                }
            } catch {
                addResult(
                    "Model Creation Test",
                    status: .failure,
                    message: "Failed to create/save test user: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func testModelRelationships() async {
        await MainActor.run {
            do {
                // Create test user and settings
                let testUser = User(
                    id: "test_rel_\(UUID().uuidString)",
                    username: "testuser_rel",
                    displayName: "Test User Rel",
                    email: "test_rel@example.com"
                )
                modelContext.insert(testUser)
                
                let settings = Settings(id: testUser.id)
                modelContext.insert(settings)
                
                try modelContext.save()
                
                addResult(
                    "Model Relationships Test",
                    status: .success,
                    message: "Successfully created related models"
                )
            } catch {
                addResult(
                    "Model Relationships Test",
                    status: .failure,
                    message: "Failed to test relationships: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func testFirebaseConnection() async {
        do {
            let db = Firestore.firestore()
            let testDoc = try await db.collection("_diagnostics").document("test").setData([
                "timestamp": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                addResult(
                    "Firebase Connection Test",
                    status: .success,
                    message: "Successfully connected to Firebase and wrote test document"
                )
            }
        } catch {
            await MainActor.run {
                addResult(
                    "Firebase Connection Test",
                    status: .failure,
                    message: "Failed to connect to Firebase: \(error.localizedDescription)"
                )
            }
        }
    }
} 