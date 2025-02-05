import SwiftUI
import SwiftData

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authService: AuthenticationService?
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationView {
            Group {
                if let authService = authService {
                    SignInContentView(
                        authService: authService,
                        email: $email,
                        password: $password,
                        username: $username,
                        isSignUp: $isSignUp,
                        showError: $showError,
                        errorMessage: $errorMessage,
                        showForgotPassword: $showForgotPassword,
                        keyboardHeight: $keyboardHeight
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            if authService == nil {
                authService = AuthenticationService(context: modelContext)
            }
        }
    }
}

private struct SignInContentView: View {
    let authService: AuthenticationService
    @Binding var email: String
    @Binding var password: String
    @Binding var username: String
    @Binding var isSignUp: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var showForgotPassword: Bool
    @Binding var keyboardHeight: CGFloat
    @Environment(\.modelContext) private var modelContext
    @State private var userService: UserSyncService?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 20)
                
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                
                Text("Welcome to ichiwabi")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Create and share daily video responses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                #if DEBUG
                // Development test button
                Button(action: {
                    Task {
                        do {
                            print("🔍 Creating UserSyncService with modelContext: \(modelContext)")
                            let userService = UserSyncService(modelContext: modelContext)
                            print("🔍 UserSyncService created successfully")
                            try await userService.signInWithTestUser()
                        } catch {
                            print("❌ Error during test sign in: \(error)")
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Test Sign In (Dev)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                #endif
                
                if !isSignUp && authService.isBiometricEnabled {
                    Button(action: {
                        Task {
                            do {
                                try await authService.authenticateWithBiometrics()
                            } catch {
                                showError = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: authService.getBiometricType() == .faceID ? "faceid" : "touchid")
                            Text("Sign in with \(authService.getBiometricType().description)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                    
                    if isSignUp {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .submitLabel(.next)
                    }
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                        .submitLabel(.done)
                }
                .padding(.horizontal)
                
                if !isSignUp {
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.caption)
                }
                
                Button(action: {
                    Task {
                        do {
                            if isSignUp {
                                guard authService.validateEmail(email) else {
                                    throw NSError(domain: "", code: -1, 
                                                userInfo: [NSLocalizedDescriptionKey: "Please enter a valid email address"])
                                }
                                guard authService.validateUsername(username) else {
                                    throw NSError(domain: "", code: -1, 
                                                userInfo: [NSLocalizedDescriptionKey: "Username must be at least 3 characters and contain only letters, numbers, and underscores"])
                                }
                                guard authService.validatePassword(password) else {
                                    throw NSError(domain: "", code: -1, 
                                                userInfo: [NSLocalizedDescriptionKey: "Password must be at least 8 characters and contain at least one uppercase letter, one number, and one symbol"])
                                }
                                try await authService.signUp(email: email, password: password, username: username)
                            } else {
                                try await authService.signIn(email: email, password: password)
                            }
                        } catch {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.caption)
                }
                
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                    .frame(height: max(20, keyboardHeight))
            }
            .padding(.vertical)
        }
        .ignoresSafeArea(.keyboard)
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let value = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                let height = value?.height ?? 0
                keyboardHeight = height
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authService: authService)
        }
    }
}

struct ForgotPasswordView: View {
    let authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title)
                    .padding(.top)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        do {
                            try await authService.resetPassword(email: email)
                            showSuccess = true
                        } catch {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Send Reset Link")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Password reset link has been sent to your email.")
            }
        }
    }
} 