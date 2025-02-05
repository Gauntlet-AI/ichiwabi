import SwiftUI

struct BiometricSettingsView: View {
    @State private var biometricService = BiometricAuthService()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            if biometricService.checkBiometricAvailability() {
                Section {
                    Toggle(isOn: $biometricService.isBiometricEnabled) {
                        HStack {
                            Image(systemName: biometricService.biometricType == .faceID ? "faceid" : "touchid")
                            Text("Use \(biometricService.biometricType.description)")
                        }
                    }
                } footer: {
                    Text("Enable biometric authentication to quickly and securely access your account.")
                }
                
                if biometricService.isBiometricEnabled {
                    Section {
                        Button("Test \(biometricService.biometricType.description)") {
                            testBiometricAuth()
                        }
                    }
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
    }
    
    private func testBiometricAuth() {
        Task {
            do {
                try await biometricService.authenticate()
                // Success handling could be added here if needed
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
} 