import Foundation
import SwiftData

/// Service to map scanned barcodes to plant varieties.
@MainActor
class BarcodeMatcherService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Attempts to find a variety that matches the scanned barcode.
    func match(barcode: String) async -> Variety? {
        // In the MVP, we use the plant database for the lookup.
        return PlantDatabaseService.lookupByBarcode(barcode)
    }
    
    /// Scans and saves a new seed record.
    func recordSeed(barcode: String, variety: Variety? = nil, gardenID: UUID? = nil) -> SeedRecord {
        let newRecord = SeedRecord(
            barcode: barcode,
            varietyID: variety?.id,
            gardenID: gardenID
        )
        modelContext.insert(newRecord)
        return newRecord
    }
}
