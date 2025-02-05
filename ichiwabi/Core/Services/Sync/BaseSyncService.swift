import Foundation
import FirebaseFirestore
import SwiftData
import Network

protocol PersistentModelWithStringID {
    var persistentModelID: String { get }
}

@MainActor
class BaseSyncService<T> where T: PersistentModel & Observable & SyncableModel & PersistentModelWithStringID {
    private let db = Firestore.firestore()
    let context: ModelContext
    private let networkMonitor = NWPathMonitor()
    @MainActor private var isOnline = true
    
    init(modelContext: ModelContext) {
        self.context = modelContext
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                // Removing automatic sync on network change
                print("💫 Network status changed - isOnline: \(path.status == .satisfied)")
            }
        }
        networkMonitor.start(queue: DispatchQueue.main)
    }
    
    // MARK: - Core Sync Operations
    
    /// Sync a single model instance to Firestore
    func sync(_ originalModel: T) async throws {
        guard isOnline else {
            let modelCopy = try await updateLocalModel(originalModel, status: .pendingUpload)
            throw SyncError.offline
        }
        
        // Validate the model before attempting to sync
        try originalModel.validate()
        
        let docRef = db.collection(T.collectionPath).document(originalModel.persistentModelID)
        
        // Check for conflicts
        if let existingDoc = try? await docRef.getDocument().data() {
            do {
                let existingModel = try T.fromFirestoreData(existingDoc, id: originalModel.persistentModelID)
                if originalModel.hasConflictsWith(existingModel) {
                    try await updateFirestore(originalModel)
                    _ = try await updateLocalModel(originalModel, status: .synced)
                    return
                }
            } catch {
                throw SyncError.invalidData("Error parsing existing model: \(error.localizedDescription)")
            }
        }
        
        // No conflict or couldn't parse existing model, proceed with update
        try await updateFirestore(originalModel)
        _ = try await updateLocalModel(originalModel, status: .synced)
    }
    
    /// Fetch and sync changes from Firestore
    func fetchChanges() async throws {
        guard isOnline else {
            throw SyncError.offline
        }
        
        let snapshot = try await db.collection(T.collectionPath).getDocuments()
        let localModels = try context.fetch(FetchDescriptor<T>())
        
        for document in snapshot.documents {
            do {
                let remoteModel = try T.fromFirestoreData(document.data(), id: document.documentID)
                
                // Check for local version
                if let localModel = localModels.first(where: { $0.persistentModelID == document.documentID }) {
                    if localModel.hasConflictsWith(remoteModel) {
                        try await updateFirestore(localModel)
                        _ = try await updateLocalModel(localModel, status: .synced)
                    } else if let remoteDate = remoteModel.lastSyncedAt,
                              let localDate = localModel.lastSyncedAt,
                              remoteDate > localDate {
                        _ = try await updateLocalModel(remoteModel, status: .synced)
                    }
                } else {
                    // No local version exists, save the remote version
                    _ = try await updateLocalModel(remoteModel, status: .synced)
                }
            } catch {
                print("Error syncing document \(document.documentID): \(error)")
                continue
            }
        }
    }
    
    /// Sync pending local changes to Firestore
    func syncPendingChanges() async throws {
        guard isOnline else {
            print("💫 Sync: Device is offline")
            throw SyncError.offline
        }
        
        print("💫 Sync: Starting to sync pending changes")
        print("💫 Sync: Model type is \(String(describing: T.self))")
        
        do {
            print("💫 Sync: Creating fetch descriptor...")
            let descriptor = FetchDescriptor<T>()
            
            print("💫 Sync: Attempting fetch...")
            let allModels = try context.fetch(descriptor)
            print("💫 Sync: Successfully fetched \(allModels.count) models")
            
            var pendingModels: [T] = []
            for model in allModels {
                print("💫 Sync: Checking model \(model.persistentModelID) with status: \(model.syncStatus)")
                if model.syncStatus == SyncStatus.pendingUpload.rawValue {
                    pendingModels.append(model)
                }
            }
            
            print("💫 Sync: Found \(pendingModels.count) pending models")
            
            for model in pendingModels {
                print("💫 Sync: Processing model \(model.persistentModelID)")
                do {
                    try model.validate()
                    print("💫 Sync: Model validation passed")
                    try await sync(model)
                    print("💫 Sync: Successfully synced model")
                } catch {
                    print("💫 Sync: Error syncing model \(model.persistentModelID): \(error)")
                    do {
                        try await updateLocalModel(model, status: .error)
                        print("💫 Sync: Updated model status to error")
                    } catch {
                        print("💫 Sync: Failed to update model status: \(error)")
                    }
                }
            }
            
            print("💫 Sync: Finished processing all pending models")
        } catch {
            print("💫 Sync: Critical error during sync: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateLocalModel(_ model: T, status: SyncStatus) async throws -> T {
        print("💫 Update: Starting update for model \(model.persistentModelID)")
        let existingModels = try context.fetch(FetchDescriptor<T>())
        
        if let existingModel = existingModels.first(where: { $0.persistentModelID == model.persistentModelID }) {
            print("💫 Update: Found existing model")
            do {
                var modelData = try await existingModel.toFirestoreData()
                modelData["syncStatus"] = status.rawValue
                modelData["lastSyncedAt"] = Timestamp(date: Date())
                let updatedModel = try T.fromFirestoreData(modelData, id: existingModel.persistentModelID)
                context.insert(updatedModel)
                try context.save()
                print("💫 Update: Successfully updated existing model")
                return updatedModel
            } catch {
                print("💫 Update: Error updating existing model: \(error)")
                throw error
            }
        }
        
        print("💫 Update: Creating new model instance")
        do {
            var modelData = try await model.toFirestoreData()
            modelData["syncStatus"] = status.rawValue
            modelData["lastSyncedAt"] = Timestamp(date: Date())
            let newModel = try T.fromFirestoreData(modelData, id: model.persistentModelID)
            context.insert(newModel)
            try context.save()
            print("💫 Update: Successfully created new model")
            return newModel
        } catch {
            print("💫 Update: Error creating new model: \(error)")
            throw error
        }
    }
    
    private func updateFirestore(_ model: T) async throws {
        try model.validate()
        let docRef = db.collection(T.collectionPath).document(model.persistentModelID)
        try await docRef.setData(model.toFirestoreData(), merge: true)
    }
    
    // MARK: - Real-time Updates
    
    func observeChanges(completion: @escaping (Result<T, Error>) -> Void) -> ListenerRegistration {
        return db.collection(T.collectionPath).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(SyncError.networkError(error)))
                return
            }
            
            guard let snapshot = snapshot else {
                completion(.failure(SyncError.invalidData("No snapshot available")))
                return
            }
            
            snapshot.documentChanges.forEach { change in
                if change.type == .modified || change.type == .added {
                    do {
                        var modelData = change.document.data()
                        modelData["syncStatus"] = SyncStatus.synced.rawValue
                        modelData["lastSyncedAt"] = Timestamp(date: Date())
                        let model = try T.fromFirestoreData(modelData, id: change.document.documentID)
                        Task { @MainActor in
                            do {
                                self?.context.insert(model)
                                try self?.context.save()
                                completion(.success(model))
                            } catch {
                                completion(.failure(error))
                            }
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Testing
    
    @MainActor
    func testSwiftDataOperations() async throws {
        print("🔍 Testing SwiftData operations")
        print("🔍 Context: \(context)")
        print("🔍 Container: \(context.container)")
        
        do {
            print("🔍 Attempting simple fetch...")
            let descriptor = FetchDescriptor<T>()
            let models = try context.fetch(descriptor)
            print("🔍 Fetch successful - found \(models.count) models")
            
            // Try to create a test model
            print("🔍 Testing model creation...")
            if let model = models.first {
                print("🔍 Found existing model: \(model.persistentModelID)")
            } else {
                print("🔍 No models found in database")
            }
        } catch {
            print("🔍 SwiftData error: \(error)")
            throw error
        }
    }
    
    deinit {
        networkMonitor.cancel()
    }
} 