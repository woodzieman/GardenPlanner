import Foundation
import SwiftData
import simd

@Model
class SurfaceZone: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String?
    var surfaceType: SurfaceZoneType
    var polygonPoints: [[Double]]  // 2D coordinates of zone boundary
    var elevation: Float = 0.0     // Height above ground (for steps, raised beds)
    var lightLevel: Double = 50.0  // 0-100, where 0 = full shade, 100 = full sun
    var wetness: WetnessLevel = WetnessLevel.moderate  // fully qualified: @Model macro rejects shorthand enum defaults
    var soilType: SoilType?
    var windExposure: WindExposure?
    var notes: String = ""
    
    // MARK: - Relationships
    
    @Relationship(inverse: \Garden.surfaceZones) var garden: Garden?
    @Relationship(deleteRule: .cascade) var plantInstances: [PlantInstance]
    
    // MARK: - Computed
    
    var area: Double {
        guard polygonPoints.count >= 3 else { return 0 }
        var sum = 0.0
        for i in 0..<polygonPoints.count {
            let j = (i + 1) % polygonPoints.count
            sum += polygonPoints[i][0] * polygonPoints[j][1]
            sum -= polygonPoints[j][0] * polygonPoints[i][1]
        }
        return abs(sum) / 2.0
    }
    
    var centerPoint: (Double, Double)? {
        guard !polygonPoints.isEmpty else { return nil }
        let avgX = polygonPoints.map { $0[0] }.reduce(0, +) / Double(polygonPoints.count)
        let avgY = polygonPoints.map { $0[1] }.reduce(0, +) / Double(polygonPoints.count)
        return (avgX, avgY)
    }
    
    var isPlantable: Bool {
        surfaceType.canAcceptPlants
    }
    
    var lightDescription: String {
        switch lightLevel {
        case 0...25: return "Shade"
        case 26...50: return "Partial Shade"
        case 51...75: return "Partial Sun"
        case 76...100: return "Full Sun"
        default: return "—"
        }
    }
    
    var wetnessDescription: String {
        switch wetness {
        case .dry: return "Dry"
        case .moderate: return "Moderate"
        case .saturated: return "Saturated"
        }
    }
    
    // MARK: - Initialization
    
    init(
        name: String? = nil,
        surfaceType: SurfaceZoneType = .gardenBed,
        polygonPoints: [[Double]] = [],
        elevation: Float = 0.0,
        lightLevel: Double = 50.0,
        wetness: WetnessLevel = .moderate,
        soilType: SoilType? = nil,
        windExposure: WindExposure? = nil,
        notes: String = "",
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.surfaceType = surfaceType
        self.polygonPoints = polygonPoints
        self.elevation = elevation
        self.lightLevel = lightLevel
        self.wetness = wetness
        self.soilType = soilType
        self.windExposure = windExposure
        self.notes = notes
        self.plantInstances = []
    }
}

// MARK: - Enums

enum SurfaceZoneType: String, Codable, CaseIterable {
    case gardenBed = "Garden Bed"
    case raisedBed = "Raised Bed/Container"
    case concrete = "Concrete/Patio"
    case path = "Foot Path"
    case lawn = "Lawn"
    case water = "Water Feature"
    case other = "Other"
    
    var canAcceptPlants: Bool {
        switch self {
        case .gardenBed, .raisedBed: return true
        case .concrete, .path, .lawn, .water, .other: return false
        }
    }
    
    var colorHex: String {
        switch self {
        case .gardenBed: return "#8B5E3C"
        case .raisedBed: return "#A0522D"
        case .concrete: return "#B0B0B0"
        case .path: return "#C4A882"
        case .lawn: return "#6B8E23"
        case .water: return "#4682B4"
        case .other: return "#808080"
        }
    }
}

enum WetnessLevel: String, Codable, CaseIterable {
    case dry = "Dry"
    case moderate = "Moderate"
    case saturated = "Saturated"
}

enum SoilType: String, Codable, CaseIterable {
    case sandy = "Sandy"
    case clay = "Clay"
    case loam = "Loam"
    case peat = "Peat"
    case chalk = "Chalk"
    case custom = "Custom"
}

enum WindExposure: String, Codable, CaseIterable {
    case sheltered = "Sheltered"
    case moderate = "Moderate"
    case exposed = "Exposed"
    case coastal = "Coastal"
}
