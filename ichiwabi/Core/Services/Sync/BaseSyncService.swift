import Foundation
import FirebaseFirestore
import SwiftData
import Network

protocol PersistentModelWithStringID {
    var persistentModelID: String { get }
}

@MainActor
class BaseSyncService<T> where T: PersistentModel & SyncableModel & PersistentModelWithStringID {
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
                if self?.isOnline == true {
                    // Trigger sync for pending changes when coming back online
                    try? await self?.syncPendingChanges()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    // MARK: - Core Sync Operations
    
    /// Sync a single model instance to Firestore
    func sync(_ model: T) async throws {
        guard isOnline else {
            // Store for later sync when offline
            try await updateLocalModel(model, status: .pendingUpload)
            throw SyncError.offline
        }
        
        // Validate the model before attempting to sync
        try model.validate()
        
        let docRef = db.collection(T.collectionPath).document(model.persistentModelID)
        
        // Check for conflicts
        if let existingDoc = try? await docRef.getDocument().data() {
            do {
                let existingModel = try T.fromFirestoreData(existingDoc, id: model.persistentModelID)
                if model.hasConflictsWith(existingModel) {
                    let mergedModel = try model.mergeChanges(from: existingModel)
                    try await updateFirestore(mergedModel)
                    try await updateLocalModel(mergedModel, status: .synced)
                    return
                }
            } catch {
                throw SyncError.invalidData("Error parsing existing model: \(error.localizedDescription)")
            }
        }
        
        // No conflict or couldn't parse existing model, proceed with update
        try await updateFirestore(model)
        try await updateLocalModel(model, status: .synced)
    }
    
    /// Fetch and sync changes from Firestore
    func fetchChanges() async throws {
        guard isOnline else {
            throw SyncError.offline
        }
        
        let snapshot = try await db.collection(T.collectionPath).getDocuments()
        let descriptor = FetchDescriptor<T>()
        let localModels = try context.fetch(descriptor)
        
        for document in snapshot.documents {
            do {
                let remoteModel = try T.fromFirestoreData(document.data(), id: document.documentID)
                
                // Check for local version
                if let localModel = localModels.first(where: { $0.persistentModelID == document.documentID }) {
                    if localModel.hasConflictsWith(remoteModel) {
                        let mergedModel = try localModel.mergeChanges(from: remoteModel)
                        try await updateFirestore(mergedModel)
                        try await updateLocalModel(mergedModel, status: .synced)
                    } else if let remoteDate = remoteModel.lastSyncedAt,
                              let localDate = localModel.lastSyncedAt,
                              remoteDate > localDate {
                        try await updateLocalModel(remoteModel, status: .synced)
                    }
                } else {
                    // No local version exists, save the remote version
                    try await updateLocalModel(remoteModel, status: .synced)
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
            throw SyncError.offline
        }
        
        let descriptor = FetchDescriptor<T>()
        let models = try context.fetch(descriptor)
        
        let pendingModels = models.filter { model in
            guard let status = SyncStatus(rawValue: model.syncStatus) else {
                return false
            }
            return status == .pendingUpload
        }
        
        // Sync each pending model individually to handle conflicts properly
        for model in pendingModels {
            do {
                try model.validate()
                try await sync(model)
            } catch {
                print("Error syncing pending model \(model.persistentModelID): \(error)")
                continue
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateFirestore(_ model: T) async throws {
        try model.validate()
        let docRef = db.collection(T.collectionPath).document(model.persistentModelID)
        try await docRef.setData(model.toFirestoreData(), merge: true)
    }
    
    private func updateLocalModel(_ model: T, status: SyncStatus) async throws {
        var updatedModel = model
        updatedModel.syncStatus = status.rawValue
        updatedModel.lastSyncedAt = Date()
        context.insert(updatedModel)
        try context.save()
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
                        let model = try T.fromFirestoreData(change.document.data(), id: change.document.documentID)
                        Task { @MainActor in
                            do {
                                try await self?.updateLocalModel(model, status: .synced)
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
    
    deinit {
        networkMonitor.cancel()
    }
} 