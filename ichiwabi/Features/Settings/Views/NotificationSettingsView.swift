import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Morning Reminder", isOn: $viewModel.isEnabled)
                    .onChange(of: viewModel.isEnabled) { oldValue, newValue in
                        Task {
                            await viewModel.toggleNotifications()
                        }
                    }
                
                if viewModel.isEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: $viewModel.reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: viewModel.reminderTime) { oldValue, newValue in
                        Task {
                            await viewModel.updateReminderTime()
                        }
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("You'll receive a daily reminder to record your dreams at the specified time.")
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
} 