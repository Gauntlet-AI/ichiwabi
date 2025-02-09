import SwiftUI
import SwiftData

// MARK: - Main View
struct BiometricSettingsView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    @State private var isAuthenticating = false
    @State private var isEnabled = false
    
    private var isAvailable: Bool {
        // Only check availability if we're not in the middle of authenticating
        guard !isAuthenticating else { return true }
        let available = authService.biometricService.checkBiometricAvailability()
        print("🔐 Biometric availability in view: \(available)")
        return available
    }
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            FormContent(
                isAvailable: isAvailable,
                isEnabled: $isEnabled,
                isAuthenticating: isAuthenticating,
                authService: authService,
                onToggle: handleBiometricToggle,
                onTest: testBiometricAuthWithFeedback,
                onReset: resetBiometricSettings
            )
            .background(Theme.darkNavy)
        }
        .navigationTitle("Biometric Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authService.isBiometricEnabled ? 
                 "Biometric authentication is working correctly!" :
                 "Biometric settings have been reset.")
        }
        .onAppear {
            isEnabled = authService.isBiometricEnabled
        }
    }
    
    private func handleBiometricToggle(isEnabled: Bool) async {
        guard isEnabled != authService.isBiometricEnabled else { return }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        if isEnabled {
            do {
                try await authService.biometricService.authenticateForSetup()
                authService.isBiometricEnabled = true
                showSuccessMessage = true
            } catch BiometricError.cancelled {
                // Just disable without showing error
                self.isEnabled = false
                authService.isBiometricEnabled = false
            } catch {
                // If authentication fails, keep it disabled
                self.isEnabled = false
                authService.isBiometricEnabled = false
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            // Handle disabling directly
            authService.isBiometricEnabled = false
            showSuccessMessage = true
        }
    }
    
    private func testBiometricAuthWithFeedback() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            try await testBiometricAuth()
            showSuccessMessage = true
        } catch BiometricError.cancelled {
            // Just ignore cancellation
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func resetBiometricSettings() {
        authService.isBiometricEnabled = false
        isEnabled = false
        showSuccessMessage = true
    }
    
    private func testBiometricAuth() async throws {
        try await authService.authenticateWithBiometrics()
    }
}

// MARK: - Form Content View
private struct FormContent: View {
    let isAvailable: Bool
    @Binding var isEnabled: Bool
    let isAuthenticating: Bool
    let authService: AuthenticationService
    let onToggle: (Bool) async -> Void
    let onTest: () async -> Void
    let onReset: () -> Void
    
    var body: some View {
        Form {
            if isAvailable {
                BiometricToggleSection(
                    isEnabled: $isEnabled,
                    isAuthenticating: isAuthenticating,
                    authService: authService,
                    onToggle: onToggle
                )
                
                if authService.isBiometricEnabled {
                    TestSection(
                        isAuthenticating: isAuthenticating,
                        authService: authService,
                        onTest: onTest
                    )
                }
                
                ResetSection(
                    isAuthenticating: isAuthenticating,
                    onReset: onReset
                )
            } else {
                UnavailableSection()
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Section Views
private struct BiometricToggleSection: View {
    @Binding var isEnabled: Bool
    let isAuthenticating: Bool
    let authService: AuthenticationService
    let onToggle: (Bool) async -> Void
    
    var body: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                HStack {
                    Image(systemName: authService.getBiometricType() == .faceID ? "faceid" : "touchid")
                    Text("Use \(authService.getBiometricType().description)")
                }
            }
            .disabled(isAuthenticating)
            .onChange(of: isEnabled) { oldValue, newValue in
                Task {
                    await onToggle(newValue)
                }
            }
        } footer: {
            Text("Enable biometric authentication to quickly and securely access your account.")
        }
        .listRowBackground(Color.clear)
        .listSectionSpacing(.compact)
    }
}

private struct TestSection: View {
    let isAuthenticating: Bool
    let authService: AuthenticationService
    let onTest: () async -> Void
    
    var body: some View {
        Section {
            Button("Test \(authService.getBiometricType().description)") {
                Task {
                    await onTest()
                }
            }
            .disabled(isAuthenticating)
        }
        .listRowBackground(Color.clear)
    }
}

private struct ResetSection: View {
    let isAuthenticating: Bool
    let onReset: () -> Void
    
    var body: some View {
        Section {
            Button("Reset Biometric Settings") {
                onReset()
            }
            .foregroundColor(.red)
            .disabled(isAuthenticating)
        } footer: {
            Text("Use this if you're having issues with biometric authentication.")
        }
        .listRowBackground(Color.clear)
    }
}

private struct UnavailableSection: View {
    var body: some View {
        Section {
            Text("Biometric authentication is not available on this device.")
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Preview Helper
extension AuthenticationService {
    @MainActor
    static var preview: AuthenticationService {
        do {
            let container = try ModelContainer(
                for: User.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = container.mainContext
            return AuthenticationService(context: context)
        } catch {
            // For previews, if we can't create the container, it's a development-time error
            let message = "Failed to create preview AuthenticationService: \(error)"
            print(message)
            fatalError(message)
        }
    }
}

#Preview {
    NavigationStack {
        BiometricSettingsView()
            .environment(AuthenticationService.preview)
    }
    .preferredColorScheme(.dark)
}
