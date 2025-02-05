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
    
    func uploadVideo(at localURL: URL, userId: String) async throws -> String {
        isUploading = true
        defer { isUploading = false }
        
        // Create a unique path for the video
        let filename = "\(UUID().uuidString).mp4"
        let path = "users/\(userId)/dreams/\(filename)"
        let storageRef = storage.reference().child(path)
        
        // Save video locally first
        let localCopy = try await saveVideoLocally(from: localURL, userId: userId, filename: filename)
        
        // Start upload
        return try await withCheckedThrowingContinuation { continuation in
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            let uploadTask = storageRef.putFile(from: localCopy, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let urlString = url?.absoluteString {
                        continuation.resume(returning: urlString)
                    } else {
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
                }
            }
            
            // Store active upload
            activeUploads[path] = uploadTask
            
            // Register background task
            registerBackgroundTask(for: path)
        }
    }
    
    func cancelUpload(for path: String) {
        activeUploads[path]?.cancel()
        activeUploads.removeValue(forKey: path)
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