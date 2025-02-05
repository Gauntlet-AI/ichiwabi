import SwiftUI

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
        Form {
            if isAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { authService.isBiometricEnabled },
                        set: { newValue in
                            if newValue {
                                // Only handle enabling - disabling is handled by the error case
                                isAuthenticating = true
                                Task {
                                    do {
                                        // Use authenticateForSetup when enabling
                                        try await authService.biometricService.authenticateForSetup()
                                        authService.isBiometricEnabled = true
                                        showSuccessMessage = true
                                    } catch BiometricError.cancelled {
                                        // Just disable without showing error
                                        authService.isBiometricEnabled = false
                                    } catch {
                                        // If authentication fails, keep it disabled
                                        authService.isBiometricEnabled = false
                                        showError = true
                                        errorMessage = error.localizedDescription
                                    }
                                    isAuthenticating = false
                                }
                            } else {
                                // Handle disabling directly
                                authService.isBiometricEnabled = false
                                showSuccessMessage = true
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: authService.getBiometricType() == .faceID ? "faceid" : "touchid")
                            Text("Use \(authService.getBiometricType().description)")
                        }
                    }
                    .disabled(isAuthenticating)
                } footer: {
                    Text("Enable biometric authentication to quickly and securely access your account.")
                }
                
                if authService.isBiometricEnabled {
                    Section {
                        Button("Test \(authService.getBiometricType().description)") {
                            isAuthenticating = true
                            Task {
                                do {
                                    try await testBiometricAuth()
                                    showSuccessMessage = true
                                } catch BiometricError.cancelled {
                                    // Just ignore cancellation
                                } catch {
                                    showError = true
                                    errorMessage = error.localizedDescription
                                }
                                isAuthenticating = false
                            }
                        }
                        .disabled(isAuthenticating)
                    }
                }
                
                Section {
                    Button("Reset Biometric Settings") {
                        authService.isBiometricEnabled = false
                        showSuccessMessage = true
                    }
                    .foregroundColor(.red)
                    .disabled(isAuthenticating)
                } footer: {
                    Text("Use this if you're having issues with biometric authentication.")
                }
            } else {
                Section {
                    Text("Biometric authentication is not available on this device.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Biometric Authentication")
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
    }
    
    private func testBiometricAuth() async throws {
        try await authService.authenticateWithBiometrics()
    }
} 