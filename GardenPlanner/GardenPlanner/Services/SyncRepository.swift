import Foundation
import CloudKit

/// Protocol for the sync repository.
/// Abstracts the sync layer so it can be swapped (CloudKit, local-only, mock).
/// Default: CloudKit private DB, disabled until user opts in.
protocol SyncRepository {
    func saveGarden(_ garden: Garden) async throws
    func loadGardens() async throws -> [Garden]
    func deleteGarden(_ id: UUID) async throws
    func isAvailable() async -> Bool
    func setupAccount() async throws
}

/// CloudKit implementation.
final class CloudKitSyncService: SyncRepository {
    private let container: CKContainer
    private var privateDB: CKDatabase?
    private var isSetup = false
    
    init() {
        // Use the app's own iCloud container (requires the CloudKit capability).
        // `privateCloudDatabase` is nil when iCloud isn't signed in — callers treat
        // that as "sync unavailable" rather than a hard failure.
        self.container = .default()
        self.privateDB = container.privateCloudDatabase
    }
    
    func isAvailable() async -> Bool {
        guard let db = privateDB else { return false }
        
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
    
    func setupAccount() async throws {
        guard !isSetup else { return }
        
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        // `default` record zone always exists; a harmless save validates access.
        let record = CKRecord(recordType: "GardenPlannerPresence", recordID: CKRecord.ID(recordName: "presence"))
        try await db.save(record)
        isSetup = true
    }
    
    func saveGarden(_ garden: Garden) async throws {
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        let record = gardenToRecord(garden)
        try await db.save(record)
    }
    
    func loadGardens() async throws -> [Garden] {
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        let query = CKQuery(recordType: "Garden", predicate: NSPredicate(value: true))
        let results = try await db.perform(query, inZoneWith: nil)
        
        return try results.compactMap { record in
            try recordToGarden(record)
        }
    }
    
    func deleteGarden(_ id: UUID) async throws {
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        try await db.deleteRecord(withID: CKRecord.ID(recordName: id.uuidString))
    }
    
    // MARK: - Record conversion
    
    private func gardenToRecord(_ garden: Garden) -> CKRecord {
        var record = CKRecord(recordType: "Garden", recordID: CKRecord.ID(recordName: garden.id.uuidString))
        record["name"] = garden.name as CKRecordValue
        record["description"] = garden.details as CKRecordValue
        record["createdDate"] = garden.createdDate as CKRecordValue
        return record
    }
    
    private func recordToGarden(_ record: CKRecord) throws -> Garden {
        let name = record["name"] as? String ?? "Unnamed"
        let details = record["description"] as? String ?? ""
        let createdDate = record["createdDate"] as? Date ?? Date()
        
        return Garden(name: name, details: details)
    }
}

enum SyncError: Error {
    case noDatabase
    case notSignedIn
    case networkError
    case decodingError(String)
}
