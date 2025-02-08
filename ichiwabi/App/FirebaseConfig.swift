import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        // Initialize Firebase services for production
        let _ = Firestore.firestore()
        let _ = Storage.storage()
        
        print("🔥 Firebase configured for production")
    }
} 