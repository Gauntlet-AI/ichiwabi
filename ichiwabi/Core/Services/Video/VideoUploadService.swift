import Foundation
import FirebaseStorage
import BackgroundTasks

@MainActor
final class VideoUploadService: ObservableObject {
    @Published private(set) var uploadProgress: Double = 0
    @Published private(set) var isUploading = false
    @Published var error: Error?
    
    private let storage = Storage.storage()
    private var activeUploads: [String: StorageUploadTask] = [:]
    
    // MARK: - Video Storage Management
    
    func uploadVideo(at localURL: URL, userId: String) async throws -> (localURL: URL, cloudURL: String) {
        isUploading = true
        defer { isUploading = false }
        
        print("🎥 Starting video upload for user: \(userId)")
        print("🎥 Original video URL: \(localURL)")
        
        // Create a unique filename
        let filename = "\(UUID().uuidString).mp4"
        let cloudPath = "users/\(userId)/dreams/\(filename)"
        let storageRef = storage.reference().child(cloudPath)
        print("🎥 Firebase Storage path: \(cloudPath)")
        
        // Save video locally first
        let localCopy = try await saveVideoLocally(from: localURL, userId: userId, filename: filename)
        print("🎥 Saved local copy at: \(localCopy)")
        
        // Start upload to Firebase Storage
        let cloudURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            print("🎥 Starting Firebase Storage upload...")
            let uploadTask = storageRef.putFile(from: localCopy, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ Upload failed with error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                print("🎥 Upload completed, getting download URL...")
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Failed to get download URL: \(error)")
                        continuation.resume(throwing: error)
                    } else if let urlString = url?.absoluteString {
                        print("✅ Got download URL: \(urlString)")
                        continuation.resume(returning: urlString)
                    } else {
                        print("❌ No download URL available")
                        continuation.resume(throwing: VideoUploadError.failedToGetDownloadURL)
                    }
                }
            }
            
            // Track upload progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                Task { @MainActor in
                    let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) /
                        Double(snapshot.progress?.totalUnitCount ?? 1)
                    self?.uploadProgress = percentComplete
                    print("🎥 Upload progress: \(Int(percentComplete * 100))%")
                }
            }
            
            // Store active upload
            activeUploads[cloudPath] = uploadTask
            
            // Register background task
            registerBackgroundTask(for: cloudPath)
        }
        
        return (localCopy, cloudURL)
    }
    
    func getVideo(localPath: String?, cloudURL: String?) async throws -> URL? {
        // First try to get from local storage
        if let localPath = localPath {
            let fileManager = FileManager.default
            let localURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(localPath)
            
            if fileManager.fileExists(atPath: localURL.path) {
                return localURL
            }
        }
        
        // If local file doesn't exist or no local path, try to download from cloud
        if let cloudURL = cloudURL, let url = URL(string: cloudURL) {
            return try await downloadVideo(from: url)
        }
        
        return nil
    }
    
    private func downloadVideo(from url: URL) async throws -> URL {
        // Get reference from URL
        let path = url.lastPathComponent
        let storageRef = storage.reference().child("users").child(path)
        
        // Create local URL for download
        let fileManager = FileManager.default
        let localURL = fileManager.temporaryDirectory.appendingPathComponent(path)
        
        // Download to local file
        _ = try await storageRef.write(toFile: localURL)
        
        return localURL
    }
    
    private func saveVideoLocally(from url: URL, userId: String, filename: String) async throws -> URL {
        let fileManager = FileManager.default
        
        // Create directory if needed
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dreamsPath = documentsPath.appendingPathComponent("dreams/\(userId)", isDirectory: true)
        try? fileManager.createDirectory(at: dreamsPath, withIntermediateDirectories: true)
        
        // Copy file
        let destinationURL = dreamsPath.appendingPathComponent(filename)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: url, to: destinationURL)
        }
        
        return destinationURL
    }
    
    func cancelUpload(for path: String) {
        activeUploads[path]?.cancel()
        activeUploads.removeValue(forKey: path)
    }
    
    private func registerBackgroundTask(for path: String) {
        let taskIdentifier = "com.ichiwabi.videoupload.\(path)"
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            // Handle background task
            guard let bgTask = task as? BGProcessingTask else { return }
            
            bgTask.expirationHandler = { [weak self] in
                self?.activeUploads[path]?.pause()
            }
            
            if let uploadTask = self.activeUploads[path] {
                uploadTask.resume()
                
                // Set up observer for completion
                uploadTask.observe(.success) { _ in
                    bgTask.setTaskCompleted(success: true)
                }
                
                uploadTask.observe(.failure) { _ in
                    bgTask.setTaskCompleted(success: false)
                }
            } else {
                bgTask.setTaskCompleted(success: false)
            }
        }
        
        // Schedule the background task
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}

// MARK: - Errors

enum VideoUploadError: LocalizedError {
    case failedToGetDownloadURL
    case uploadCancelled
    
    var errorDescription: String? {
        switch self {
        case .failedToGetDownloadURL:
            return "Failed to get download URL for uploaded video"
        case .uploadCancelled:
            return "Video upload was cancelled"
        }
    }
} 