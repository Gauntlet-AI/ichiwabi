import Foundation
import FirebaseStorage
import UIKit

enum StorageError: LocalizedError {
    case invalidImageData
    case uploadFailed(Error)
    case downloadFailed(Error)
    case urlRetrievalFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .uploadFailed(let error):
            return "Failed to upload image: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download image: \(error.localizedDescription)"
        case .urlRetrievalFailed:
            return "Failed to get download URL"
        }
    }
}

actor StorageService {
    private let storage = Storage.storage().reference()
    
    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> URL {
        // Ensure the image data is valid
        guard let _ = UIImage(data: imageData) else {
            throw StorageError.invalidImageData
        }
        
        // Create a reference to the profile photo location
        let photoRef = storage.child("profile_photos/\(userId).jpg")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            // Upload the image data
            _ = try await photoRef.putDataAsync(imageData, metadata: metadata)
            
            // Get the download URL
            let downloadURL = try await photoRef.downloadURL()
            return downloadURL
        } catch {
            throw StorageError.uploadFailed(error)
        }
    }
    
    func deleteProfilePhoto(userId: String) async throws {
        let photoRef = storage.child("profile_photos/\(userId).jpg")
        do {
            try await photoRef.delete()
        } catch {
            // If the file doesn't exist, we can ignore the error
            if (error as NSError).domain == StorageErrorDomain &&
                (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                return
            }
            throw error
        }
    }
} 