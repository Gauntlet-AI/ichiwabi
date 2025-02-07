import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import SwiftData

@Observable
final class AuthenticationService {
    enum AuthState {
        case signedIn
        case signedOut
        case loading
    }
    
    enum AuthError: LocalizedError {
        case notAuthenticated
        case invalidCredentials
        case networkError
        case biometricError(String)
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please sign in with your email and password first to enable biometric authentication"
            case .invalidCredentials:
                return "Invalid email or password"
            case .networkError:
                return "Network error occurred. Please check your connection"
            case .biometricError(let message):
                return message
            case .unknown:
                return "An unexpected error occurred"
            }
        }
    }
    
    // MARK: - Properties
    static let lastSignedInEmailKey = "lastSignedInEmail"
    
    private let auth = Auth.auth()
    let context: ModelContext
    private let syncService: UserSyncService
    private var currentNonce: String?
    let biometricService = BiometricAuthService()
    private let defaults = UserDefaults.standard
    
    var authState: AuthState = .loading
    var currentUser: User?
    
    // MARK: - Initialization
    @MainActor
    init(context: ModelContext) {
        print("🔐 Initializing AuthenticationService")
        self.context = context
        self.syncService = UserSyncService(modelContext: context)
        print("🔐 Created UserSyncService")
        setupAuthStateHandler()
        print("🔐 Auth state handler setup complete")
        
        // Check initial auth state
        if let currentFirebaseUser = auth.currentUser {
            print("🔐 Found existing Firebase user on init: \(currentFirebaseUser.uid)")
        } else {
            print("🔐 No existing Firebase user on init")
        }
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private func setupAuthStateHandler() {
        print("🔐 Setting up auth state handler")
        // Remove any existing handler
        if let existingHandle = authStateHandle {
            print("🔐 Removing existing auth state handler")
            auth.removeStateDidChangeListener(existingHandle)
        }
        
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            print("🔐 Auth state change detected")
            Task { @MainActor in
                guard let self = self else {
                    print("🔐 Self is nil in auth state handler")
                    return
                }
                
                print("🔐 Auth state changed. User: \(user?.uid ?? "nil")")
                print("🔐 Current auth state: \(self.authState)")
                
                self.handleAuthStateChange(user)
            }
        }
    }
    
    private func handleAuthStateChange(_ user: FirebaseAuth.User?) {
        print("\n🔐 ==================== AUTH STATE CHANGE ====================")
        print("🔐 User: \(user?.uid ?? "nil")")
        
        Task { @MainActor in
            do {
                if let user = user {
                    print("🔐 User is signed in")
                    print("🔐 Email: \(user.email ?? "none")")
                    print("🔐 Display name: \(user.displayName ?? "none")")
                    
                    // Sync user data
                    print("🔐 Starting user sync")
                    try await syncService.syncCurrentUser()
                    print("🔐 User sync completed")
                    
                    // Check local user data
                    let descriptor = FetchDescriptor<User>()
                    do {
                        let allUsers = try context.fetch(descriptor)
                        print("🔐 Found \(allUsers.count) users in SwiftData")
                        print("🔐 User IDs: \(allUsers.map { $0.id }.joined(separator: ", "))")
                        
                        if let matchingUser = allUsers.first(where: { $0.id == user.uid }) {
                            print("🔐 Found matching user in SwiftData")
                            print("🔐 Username: \(matchingUser.username)")
                            print("🔐 Display name: \(matchingUser.displayName)")
                            print("🔐 Profile complete: \(matchingUser.isProfileComplete)")
                            print("🔐 Terms accepted: \(matchingUser.hasAcceptedTerms)")
                            self.currentUser = matchingUser
                            print("🔐 Set currentUser to: \(matchingUser.id)")
                            self.authState = .signedIn
                            print("🔐 Set authState to: signedIn")
                        } else {
                            print("⚠️ User is signed in but no matching user data found")
                            print("⚠️ Available user IDs: \(allUsers.map { $0.id }.joined(separator: ", "))")
                            print("⚠️ Setting authState to signedOut")
                            self.authState = .signedOut
                        }
                    } catch {
                        print("🔐 Error fetching users from SwiftData: \(error)")
                        print("🔐 Error details: \(error.localizedDescription)")
                        self.authState = .signedOut
                    }
                } else {
                    print("🔐 No user signed in")
                    self.currentUser = nil
                    self.authState = .signedOut
                }
            } catch {
                print("❌ Error during auth state change: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                self.currentUser = nil
                self.authState = .signedOut
            }
            print("🔐 ==================== AUTH STATE CHANGE END ====================\n")
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, username: String) async throws {
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let changeRequest = authResult.user.createProfileChangeRequest()
        changeRequest.displayName = username
        try await changeRequest.commitChanges()
    }
    
    func signIn(email: String, password: String) async throws {
        print("🔐 Starting sign in process for email: \(email)")
        // First sign in
        let result = try await auth.signIn(withEmail: email, password: password)
        print("🔐 Firebase sign in successful for user: \(result.user.uid)")
        
        // If successful, store email for biometric auth
        defaults.set(email, forKey: AuthenticationService.lastSignedInEmailKey)
        print("🔐 Stored email for biometric auth")
        
        // Store the authentication token securely
        if let user = auth.currentUser {
            print("🔐 Getting ID token for user")
            let token = try await user.getIDToken()
            print("🔐 Got ID token, storing in keychain")
            try storeAuthToken(token)
            print("🔐 Sign in process completed successfully")
        } else {
            print("🔐 Error: Current user is nil after successful sign in")
            throw AuthError.unknown
        }
    }
    
    func signOut() throws {
        print("🔐 Signing out...")
        // Remove auth state listener
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
            authStateHandle = nil
        }
        
        // First sign out from Firebase
        try auth.signOut()
        
        // Clear stored email
        defaults.removeObject(forKey: AuthenticationService.lastSignedInEmailKey)
        
        // Clear stored auth token from keychain
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "FirebaseAuthToken",
            kSecAttrAccessGroup: "\(Bundle.main.bundleIdentifier ?? "com.ichiwabi.app").keychain" as CFString
        ]
        let status = SecItemDelete(query as CFDictionary)
        print("🔐 Keychain clear status: \(status)")
        
        // Reset biometric state
        biometricService.resetSettings()
        
        print("🔐 Sign out complete")
    }
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Sign in with Apple
    
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
            }
            
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce,
                accessToken: nil
            )
            
            try await auth.signIn(with: credential)
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Validation
    
    func validatePassword(_ password: String) -> Bool {
        print("🔐 Validating password for security requirements...")
        
        // At least 8 characters
        guard password.count >= 8 else {
            print("🔐 Password validation failed: too short")
            return false
        }
        
        // At least one uppercase letter
        guard password.contains(where: { $0.isUppercase }) else {
            print("🔐 Password validation failed: missing uppercase letter")
            return false
        }
        
        // At least one number
        guard password.contains(where: { $0.isNumber }) else {
            print("🔐 Password validation failed: missing number")
            return false
        }
        
        // At least one symbol
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        guard password.unicodeScalars.contains(where: symbols.contains) else {
            print("🔐 Password validation failed: missing symbol")
            return false
        }
        
        print("🔐 Password validation passed")
        return true
    }
    
    func validateEmail(_ email: String) -> Bool {
        print("🔐 Validating email format: \(email)")
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isValid = emailPredicate.evaluate(with: email)
        print("🔐 Email validation \(isValid ? "passed" : "failed")")
        return isValid
    }
    
    func validateUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    // MARK: - Helper Functions
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    func authenticateWithBiometrics() async throws {
        print("🔐 Starting biometric authentication...")
        
        // Get stored email
        guard defaults.string(forKey: AuthenticationService.lastSignedInEmailKey) != nil else {
            print("🔐 No stored email found")
            throw AuthError.notAuthenticated
        }
        
        // First verify biometric
        try await biometricService.authenticate()
        
        // Then try to sign in with the stored token
        if auth.currentUser == nil {
            // Try to retrieve the stored token
            guard let token = try retrieveAuthToken() else {
                print("🔐 No stored token found")
                throw AuthError.biometricError("Please sign in with email and password first to set up biometric authentication")
            }
            
            print("🔐 Attempting to sign in with stored token...")
            // Sign in with the custom token
            do {
                try await auth.signIn(withCustomToken: token)
                print("🔐 Successfully signed in with token")
            } catch {
                print("🔐 Error signing in with token: \(error)")
                // If token sign-in fails, we need to sign in normally
                throw AuthError.biometricError("Please sign in with email and password to refresh your authentication")
            }
        } else {
            print("🔐 User is already signed in")
        }
    }
    
    func isBiometricAuthAvailable() -> Bool {
        return biometricService.checkBiometricAvailability()
    }
    
    func getBiometricType() -> BiometricType {
        return biometricService.biometricType
    }
    
    var isBiometricEnabled: Bool {
        get { biometricService.isBiometricEnabled }
        set { biometricService.isBiometricEnabled = newValue }
    }
    
    private func storeAuthToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw AuthError.biometricError("Failed to convert token to data")
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "FirebaseAuthToken",
            kSecValueData: tokenData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        print("🔐 Storing auth token in keychain...")
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Token already exists, update it
            let updateQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: "FirebaseAuthToken"
            ]
            let updateAttributes: [CFString: Any] = [
                kSecValueData: tokenData
            ]
            print("🔐 Updating existing token in keychain...")
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                print("🔐 Error updating token in keychain: \(updateStatus)")
                throw AuthError.biometricError("Failed to update authentication token")
            }
            print("🔐 Token updated successfully")
        } else if status != errSecSuccess {
            print("🔐 Error storing token in keychain: \(status)")
            throw AuthError.biometricError("Failed to store authentication token")
        } else {
            print("🔐 Token stored successfully")
        }
    }
    
    private func retrieveAuthToken() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "FirebaseAuthToken",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        print("🔐 Retrieving auth token from keychain...")
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            print("🔐 Token retrieved successfully")
            return token
        }
        
        if status != errSecItemNotFound {
            print("🔐 Error retrieving token from keychain: \(status)")
        }
        return nil
    }
} 
