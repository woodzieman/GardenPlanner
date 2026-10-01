import Foundation
import SwiftData

@Model
class PlantInstance: Identifiable {
    @Attribute(.unique) var id: UUID
    var varietyName: String
    var quantity: Int = 1
    var plantedDate: Date?
    var status: PlantStatus = PlantStatus.planted  // fully qualified: @Model macro rejects shorthand enum defaults
    var notes: String = ""
    var rowNumber: Int?
    var squareRow: Int?     // SFG square coordinates (tuples aren't persistable)
    var squareColumn: Int?
    var x: Double?   // 2D position on map
    var y: Double?
    
    // MARK: - Relationships
    
    @Relationship(inverse: \SurfaceZone.plantInstances) var zone: SurfaceZone?
    @Relationship(inverse: \Garden.plantInstances) var garden: Garden?
    var variety: Variety?
    
    // MARK: - Computed
    
    var harvestDate: Date? {
        guard let variety = variety, let plantedDate = plantedDate else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: variety.daysToMature, to: plantedDate)
    }
    
    var transplantDate: Date? {
        guard let variety = variety else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -variety.transplantOffset, to: plantedDate ?? Date())
    }
    
    var sowDate: Date? {
        guard let variety = variety else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -variety.sowOffset, to: plantedDate ?? Date())
    }
    
    var daysUntilHarvest: Int? {
        guard let harvestDate = harvestDate else { return nil }
        return max(0, Int(Date().timeIntervalSince(harvestDate).days))
    }
    
    var isWarning: Bool {
        guard let zone = zone, let variety = variety else { return false }
        let sunMatch = variety.sunReq.approximates(lightLevel: zone.lightLevel)
        let moistureMatch = variety.moistureReq.approximates(wetness: zone.wetness.rawValue)
        return !(sunMatch && moistureMatch)
    }
    
    // MARK: - Initialization
    
    init(
        varietyName: String,
        quantity: Int = 1,
        plantedDate: Date? = nil,
        status: PlantStatus = PlantStatus.planted,
        notes: String = "",
        rowNumber: Int? = nil,
        squareRow: Int? = nil,
        squareColumn: Int? = nil,
        x: Double? = nil,
        y: Double? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.varietyName = varietyName
        self.quantity = quantity
        self.plantedDate = plantedDate
        self.status = status
        self.notes = notes
        self.rowNumber = rowNumber
        self.squareRow = squareRow
        self.squareColumn = squareColumn
        self.x = x
        self.y = y
    }
}

enum PlantStatus: String, Codable {
    case planted = "Planted"
    case germinating = "Germinating"
    case seedling = "Seedling"
    case transplanted = "Transplanted"
    case maturing = "Maturing"
    case harvesting = "Harvesting"
    case dead = "Dead"
    case harvested = "Harvested"
}
