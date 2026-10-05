import Foundation
import SwiftData

/// A plant variety with all planting metadata.
/// Curated from USDA/extension/seed-catalog sources.
/// Shipped as versioned in-app JSON — works offline, no server.
struct Variety: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let family: String
    let category: PlantCategory
    let spacing: Double       // cm (plant spacing)
    let depth: Double         // cm (planting depth)
    let daysToMature: Int     // days to harvest
    let sunReq: SunRequirement
    let moistureReq: MoistureRequirement
    let frostTolerance: FrostTolerance
    let waterNeed: WaterNeed  // liters per week
    let sowOffset: Int        // days before transplant (negative = sow earlier)
    let transplantOffset: Int // days before harvest to transplant
    let harvestWindow: Int    // days from transplant to harvest window
    let harvestWindowText: String?  // original display text from plants.json (e.g. "60-70 days")
    let companions: [String]
    let antagonists: [String]
    let sfgPerSquare: Int     // plants per square foot (SFG)
    let barcode: String?       // Scanned barcode for quick matching
    let matureHeight: Double  // cm
    let matureWidth: Double   // cm
    
    init(
        id: UUID = UUID(),
        name: String,
        family: String,
        category: PlantCategory,
        spacing: Double,
        depth: Double,
        daysToMature: Int,
        sunReq: SunRequirement,
        moistureReq: MoistureRequirement,
        frostTolerance: FrostTolerance,
        waterNeed: WaterNeed,
        sowOffset: Int,
        transplantOffset: Int,
        harvestWindow: Int,
        harvestWindowText: String? = nil,
        companions: [String] = [],
        antagonists: [String] = [],
        sfgPerSquare: Int,
        barcode: String? = nil,
        matureHeight: Double = 0,
        matureWidth: Double = 0
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.category = category
        self.spacing = spacing
        self.depth = depth
        self.daysToMature = daysToMature
        self.sunReq = sunReq
        self.moistureReq = moistureReq
        self.frostTolerance = frostTolerance
        self.waterNeed = waterNeed
        self.sowOffset = sowOffset
        self.transplantOffset = transplantOffset
        self.harvestWindow = harvestWindow
        self.companions = companions
        self.antagonists = antagonists
        self.sfgPerSquare = sfgPerSquare
        self.barcode = barcode
        self.matureHeight = matureHeight
        self.matureWidth = matureWidth
        self.harvestWindowText = harvestWindowText
    }
    
    /// Tolerant decoder: the bundled plants.json ships `harvestWindow` as a display
    /// string ("60-70 days", "Year 3+: April-June, 6-8 weeks"), so we accept either
    /// an Int or a String and parse a best-effort day count.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.family = try c.decodeIfPresent(String.self, forKey: .family) ?? ""
        self.category = try c.decodeIfPresent(PlantCategory.self, forKey: .category) ?? .vegetable
        self.spacing = try c.decodeIfPresent(Double.self, forKey: .spacing) ?? 10
        self.depth = try c.decodeIfPresent(Double.self, forKey: .depth) ?? 2
        self.daysToMature = try c.decodeIfPresent(Int.self, forKey: .daysToMature) ?? 60
        self.sunReq = try c.decodeIfPresent(SunRequirement.self, forKey: .sunReq) ?? .fullSun
        self.moistureReq = try c.decodeIfPresent(MoistureRequirement.self, forKey: .moistureReq) ?? .moderate
        self.frostTolerance = try c.decodeIfPresent(FrostTolerance.self, forKey: .frostTolerance) ?? .hardy
        self.waterNeed = try c.decodeIfPresent(WaterNeed.self, forKey: .waterNeed) ?? .moderate
        self.sowOffset = try c.decodeIfPresent(Int.self, forKey: .sowOffset) ?? 0
        self.transplantOffset = try c.decodeIfPresent(Int.self, forKey: .transplantOffset) ?? 0
        self.companions = try c.decodeIfPresent([String].self, forKey: .companions) ?? []
        self.antagonists = try c.decodeIfPresent([String].self, forKey: .antagonists) ?? []
        self.sfgPerSquare = try c.decodeIfPresent(Int.self, forKey: .sfgPerSquare) ?? 1
        self.barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        self.matureHeight = try c.decodeIfPresent(Double.self, forKey: .matureHeight) ?? 0
        self.matureWidth = try c.decodeIfPresent(Double.self, forKey: .matureWidth) ?? 0
        
        // harvestWindow: Int, or a display string we parse into days.
        if let intValue = try? c.decodeIfPresent(Int.self, forKey: .harvestWindow) {
            self.harvestWindow = intValue
            self.harvestWindowText = nil
        } else {
            let text = try c.decodeIfPresent(String.self, forKey: .harvestWindow)
            self.harvestWindow = text.flatMap { Variety.parseHarvestWindowDays($0) } ?? 30
            self.harvestWindowText = text
        }
    }
    
    /// Best-effort day count from a harvest-window string.
    /// "60-70 days" → 60, "6-8 weeks" → 42, "Year 3+…" → 21
    private static func parseHarvestWindowDays(_ string: String) -> Int? {
        let lowered = string.lowercased()
        let numbers = lowered.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        guard let first = numbers.first else { return nil }
        return lowered.contains("week") ? first * 7 : first
    }
}

// MARK: - Plant Enums

enum PlantCategory: String, Codable, CaseIterable {
    case vegetable
    case herb
    case flower
    case fruit
    case root
    case legume
    case gourd
    case allium
    case brassica
    case nightshade
    case cucurbit
    case leafyGreen
    case other
}

enum SunRequirement: String, Codable {
    case fullShade
    case partialShade
    case partialSun
    case fullSun
    
    /// Check if this sun requirement is compatible with a light level.
    func approximates(lightLevel: Double) -> Bool {
        switch self {
        case .fullShade:
            return lightLevel <= 25
        case .partialShade:
            return lightLevel >= 15 && lightLevel <= 60
        case .partialSun:
            return lightLevel >= 30 && lightLevel <= 75
        case .fullSun:
            return lightLevel >= 60
        }
    }
}

enum MoistureRequirement: String, Codable {
    case low
    case moderate
    case high
    
    func approximates(wetness: String) -> Bool {
        switch self {
        case .low:
            return wetness == "Dry" || wetness == "Moderate"
        case .moderate:
            return wetness == "Moderate"
        case .high:
            return wetness == "Saturated" || wetness == "Moderate"
        }
    }
}

enum FrostTolerance: String, Codable {
    case tender
    case lightFrost
    case moderateFrost
    case hardy
}

enum WaterNeed: String, Codable, CaseIterable {
    case low
    case moderate
    case high
    case veryHigh
    
    /// User-facing display (plants.json stores the case names, e.g. "moderate").
    var displayValue: String {
        switch self {
        case .low: return "< 2L/week"
        case .moderate: return "2-4L/week"
        case .high: return "4-6L/week"
        case .veryHigh: return "> 6L/week"
        }
    }
}

// MARK: - Planting Window

struct PlantingWindow: Identifiable {
    let id = UUID()
    let variety: Variety
    let usdaZone: String
    let lastFrostDate: String?
    let firstFrostDate: String?
    let lightLevel: Double
    let zoneType: SurfaceZoneType
}

// MARK: - Profile

@Model
final class Profile: Identifiable {
    @Attribute(.unique) var id: UUID
    
    var location: String?
    var usdaZone: String = "5"
    var lastFrostDate: String? = "Apr 15"
    var firstFrostDate: String? = "Oct 15"
    var householdSize: Int = 1
    var units: UnitSystem = UnitSystem.metric  // fully qualified: @Model macro rejects shorthand enum defaults
    var hasLiDAR: Bool = false
    
    var isValid: Bool {
        usdaZone != "0" && (lastFrostDate != nil || firstFrostDate != nil)
    }
    
    init(
        id: UUID = UUID(),
        location: String? = nil,
        usdaZone: String = "5",
        lastFrostDate: String? = "Apr 15",
        firstFrostDate: String? = "Oct 15",
        householdSize: Int = 1,
        units: UnitSystem = .metric
    ) {
        self.id = id
        self.location = location
        self.usdaZone = usdaZone
        self.lastFrostDate = lastFrostDate
        self.firstFrostDate = firstFrostDate
        self.householdSize = householdSize
        self.units = units
    }
}

// MARK: - Scan

@Model
class Scan: Identifiable {
    @Attribute(.unique) var id: UUID
    var capturedDate: Date
    var meshURL: String?   // Local URL to saved .reality file
    var heightmapData: [Float]?
    var boundary: [[Double]]?
    var processed: Bool = false
    
    @Relationship(inverse: \Garden.scans) var garden: Garden?
    
    init(
        id: UUID = UUID(),
        capturedDate: Date = Date(),
        meshURL: String? = nil,
        heightmapData: [Float]? = nil,
        boundary: [[Double]]? = nil,
        processed: Bool = false
    ) {
        self.id = id
        self.capturedDate = capturedDate
        self.meshURL = meshURL
        self.heightmapData = heightmapData
        self.boundary = boundary
        self.processed = processed
    }
}
