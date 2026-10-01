import Foundation
import SwiftData

@Model
class HarvestRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var plantName: String
    var quantity: Int
    var harvestDate: Date
    var notes: String?
    
    init(
        id: UUID = UUID(),
        plantName: String,
        quantity: Int = 1,
        harvestDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.plantName = plantName
        self.quantity = quantity
        self.harvestDate = harvestDate
        self.notes = notes
    }
}
