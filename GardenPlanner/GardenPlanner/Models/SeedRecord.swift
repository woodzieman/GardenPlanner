import Foundation
import SwiftData

@Model
class SeedRecord {
    @Attribute(.unique) var barcode: String
    var varietyID: UUID?
    var scannedDate: Date
    var notes: String
    var gardenID: UUID?
    
    // Relationship to the variety (if matched)
    @Relationship(deleteRule: .nullify) var variety: Variety?
    
    init(
        barcode: String,
        varietyID: UUID? = nil,
        scannedDate: Date = Date(),
        notes: String = "",
        gardenID: UUID? = nil
    ) {
        self.barcode = barcode
        self.varietyID = varietyID
        self.scannedDate = scannedDate
        self.notes = notes
        self.gardenID = gardenID
    }
}
