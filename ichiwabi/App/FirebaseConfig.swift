import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        // Initialize Firebase services for production
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        print("🔥 Firebase configured for production")
    }
} 