import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        #if DEBUG
        print("🔥 Configuring Firebase emulators")
        // Connect to local emulators
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        Firestore.firestore().useEmulator(withHost: "localhost", port: 8080)
        Storage.storage().useEmulator(withHost: "localhost", port: 9199)
        #endif
    }
} 