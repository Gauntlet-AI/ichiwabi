import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        #if DEBUG
        print("🔥 Configuring Firebase emulators")
        // Connect to local emulators
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        Firestore.firestore().useEmulator(withHost: "localhost", port: 8080)
        #endif
    }
} 