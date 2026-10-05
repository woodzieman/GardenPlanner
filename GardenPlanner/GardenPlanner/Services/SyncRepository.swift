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
        guard privateDB != nil else { return false }
        
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
        _ = try await db.save(record)
        isSetup = true
    }
    
    func saveGarden(_ garden: Garden) async throws {
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        let record = gardenToRecord(garden)
        _ = try await db.save(record)
    }
    
    func loadGardens() async throws -> [Garden] {
        guard let db = privateDB else {
            throw SyncError.noDatabase
        }
        
        let query = CKQuery(recordType: "Garden", predicate: NSPredicate(format: "TRUEPREDICATE"))
        
        // The server returns up to 100 records per batch — far more than a
        // single user will keep as gardens — so the first batch is the full set.
        let (matchResults, _) = try await db.records(matching: query, inZoneWith: nil)
        let records = try matchResults.map { try $0.1.get() }
        
        return records.compactMap { record in
            recordToGarden(record)
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
        let record = CKRecord(recordType: "Garden", recordID: CKRecord.ID(recordName: garden.id.uuidString))
        record["name"] = garden.name as CKRecordValue
        record["description"] = garden.details as CKRecordValue
        record["createdDate"] = garden.createdDate as CKRecordValue
        return record
    }
    
    private func recordToGarden(_ record: CKRecord) -> Garden {
        let name = record["name"] as? String ?? "Unnamed"
        let details = record["description"] as? String ?? ""
        // Preserve the remote garden's identity so sync round-trips don't fork.
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
        return Garden(name: name, details: details, id: id)
    }
}

enum SyncError: Error {
    case noDatabase
    case notSignedIn
    case networkError
    case decodingError(String)
}
