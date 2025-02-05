import Foundation
import FirebaseStorage
import UIKit

enum StorageError: LocalizedError {
    case invalidImageData
    case uploadFailed(Error)
    case downloadFailed(Error)
    case urlRetrievalFailed
    case invalidURL
    
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
        case .invalidURL:
            return "Invalid URL received from storage"
        }
    }
}

actor StorageService {
    private let storage = Storage.storage().reference()
    
    init() {
        print("📸 Initializing StorageService")
        print("📸 Storage bucket: \(Storage.storage().app.options.storageBucket ?? "none")")
    }
    
    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> URL {
        print("📸 Starting photo upload for user: \(userId)")
        print("📸 Storage reference path: \(storage.fullPath)")
        print("📸 Storage bucket: \(Storage.storage().app.options.storageBucket ?? "none")")
        
        // Ensure the image data is valid
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data")
            throw StorageError.invalidImageData
        }
        
        // Compress the image if needed
        guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to compress image")
            throw StorageError.invalidImageData
        }
        
        // Create a reference to the profile photo location
        let photoRef = storage.child("profile_photos/\(userId).jpg")
        print("📸 Upload path: \(photoRef.fullPath)")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            // Upload the image data
            let uploadTask = try await photoRef.putDataAsync(compressedData, metadata: metadata)
            print("📸 Upload task completed")
            print("📸 Metadata: \(String(describing: uploadTask))")
            
            // Add a small delay to ensure the upload is complete
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Get the download URL with retries
            for attempt in 1...3 {
                do {
                    print("📸 Attempt \(attempt) to get download URL")
                    let downloadURL = try await photoRef.downloadURL()
                    print("📸 Got download URL: \(downloadURL.absoluteString)")
                    
                    // Validate the URL
                    guard downloadURL.absoluteString.starts(with: "https://") else {
                        print("❌ Invalid URL format")
                        throw StorageError.invalidURL
                    }
                    
                    return downloadURL
                } catch {
                    print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt == 3 {
                        throw StorageError.downloadFailed(error)
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay between retries
                }
            }
            
            throw StorageError.urlRetrievalFailed
        } catch {
            print("❌ Upload failed with error: \(error.localizedDescription)")
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