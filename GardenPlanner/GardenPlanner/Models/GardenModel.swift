import Foundation
import SwiftData

@Model
class Garden: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var details: String = ""   // 'description' is reserved by the SwiftData macro
    var createdDate: Date
    var lastScanDate: Date?
    
    // MARK: - Relationships
    
    @Relationship(deleteRule: .cascade) var surfaceZones: [SurfaceZone]
    @Relationship(deleteRule: .cascade) var plantInstances: [PlantInstance]
    @Relationship(deleteRule: .cascade) var scans: [Scan]
    var profile: Profile?
    
    // MARK: - Computed
    
    var totalArea: Double {
        surfaceZones.reduce(0) { $0 + $1.area }
    }
    
    var plantableZoneCount: Int {
        surfaceZones.filter { $0.isPlantable }.count
    }
    
    var plantCount: Int {
        plantInstances.count
    }
    
    // MARK: - Initialization
    
    init(
        name: String,
        details: String = "",
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.createdDate = Date()
        self.surfaceZones = []
        self.plantInstances = []
        self.scans = []
        self.profile = Profile()
    }
}

extension Garden {
    /// Compute planting dates for a variety in a specific zone.
    func computePlantingDates(for variety: Variety, in zone: SurfaceZone) -> PlantingWindow {
        let profile = self.profile ?? Profile()
        return PlantingWindow(
            variety: variety,
            usdaZone: profile.usdaZone,
            lastFrostDate: profile.lastFrostDate,
            firstFrostDate: profile.firstFrostDate,
            lightLevel: zone.lightLevel,
            zoneType: zone.surfaceType
        )
    }
    
    /// Get plants that have light/wetness mismatch warnings.
    var flaggedPlants: [PlantInstance] {
        guard let profile = profile, !profile.isValid else { return [] }
        
        return plantInstances.filter { plant in
            guard let zone = plant.zone, let variety = plant.variety else { return false }
            return !isValid(variety: variety, in: zone)
        }
    }
    
    private func isValid(variety: Variety, in zone: SurfaceZone) -> Bool {
        let sunMatch = variety.sunReq.approximates(lightLevel: zone.lightLevel)
        let moistureMatch = variety.moistureReq.approximates(wetness: zone.wetness.rawValue)
        return sunMatch && moistureMatch
    }
}
