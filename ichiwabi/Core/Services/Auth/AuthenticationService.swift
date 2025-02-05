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
    private let auth = Auth.auth()
    let context: ModelContext
    private let syncService: UserSyncService
    private var currentNonce: String?
    private let biometricService = BiometricAuthService()
    private let defaults = UserDefaults.standard
    private let lastSignedInEmailKey = "lastSignedInEmail"
    
    var authState: AuthState = .loading
    var currentUser: User?
    
    // MARK: - Initialization
    @MainActor
    init(context: ModelContext) {
        self.context = context
        self.syncService = UserSyncService(modelContext: context)
        Task {
            setupAuthStateHandler()
        }
    }
    
    private func setupAuthStateHandler() {
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                if let user = user {
                    self.authState = .signedIn
                    do {
                        try await self.syncService.syncCurrentUser()
                    } catch {
                        print("Error syncing user: \(error)")
                    }
                } else {
                    self.authState = .signedOut
                    self.currentUser = nil
                }
            }
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
        try await auth.signIn(withEmail: email, password: password)
        // Store email for biometric auth
        defaults.set(email, forKey: lastSignedInEmailKey)
    }
    
    func signOut() throws {
        try auth.signOut()
        // Clear stored email
        defaults.removeObject(forKey: lastSignedInEmailKey)
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
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            try await auth.signIn(with: credential)
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Validation
    
    func validatePassword(_ password: String) -> Bool {
        // At least 8 characters
        guard password.count >= 8 else { return false }
        
        // At least one uppercase letter
        guard password.contains(where: { $0.isUppercase }) else { return false }
        
        // At least one number
        guard password.contains(where: { $0.isNumber }) else { return false }
        
        // At least one symbol
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        guard password.unicodeScalars.contains(where: symbols.contains) else { return false }
        
        return true
    }
    
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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
        // Get stored email
        guard let email = defaults.string(forKey: lastSignedInEmailKey) else {
            throw AuthError.notAuthenticated
        }
        
        // First verify biometric
        try await biometricService.authenticate()
        
        // Then try to sign in with the stored token
        if auth.currentUser == nil {
            // We need to reauthenticate since we're signed out
            // For security reasons, we'll throw an error and ask the user to sign in normally first
            throw AuthError.notAuthenticated
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
} 