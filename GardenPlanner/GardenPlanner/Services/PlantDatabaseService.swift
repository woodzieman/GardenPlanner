import Foundation

/// Loads and manages the in-app plant database.
/// Data is shipped as a versioned JSON file — works offline, no server.
///
/// Sources: USDA plants database, extension recommendations, seed catalogs.
/// ~150 plants / 600+ varieties from the start.

struct PlantDatabaseService {
    static let version = "2.0.0"

    /// Session cache — the bundled database is static, so decoding once and
    /// reusing keeps search and list views fast.
    private static var cachedVarieties: [Variety]?
    
    /// Load all varieties from the bundled JSON file (cached after first load).
    static func loadVarieties() -> [Variety] {
        if let cached = cachedVarieties { return cached }
        
        guard let url = Bundle.main.url(forResource: "plants", withExtension: "json") else {
            print("⚠️ plants.json not found in bundle — using demo data")
            cachedVarieties = demoVarieties
            return demoVarieties
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let wrapped = try decoder.decode(VarietyListWrapper.self, from: data)
            cachedVarieties = wrapped.varieties
            return wrapped.varieties
        } catch {
            print("⚠️ Failed to load plants.json: \(error.localizedDescription)")
            cachedVarieties = demoVarieties
            return demoVarieties
        }
    }
    
    /// Search varieties by name (case-insensitive substring match).
    static func search(query: String) -> [Variety] {
        let query = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return loadVarieties() }
        
        return loadVarieties().filter { variety in
            variety.name.lowercased().contains(query) ||
            variety.family.lowercased().contains(query)
        }
    }
    
    /// Get varieties by category.
    static func varieties(by category: PlantCategory) -> [Variety] {
        loadVarieties().filter { $0.category == category }
    }
    
    /// Get companion-compatible varieties for a given variety name.
    static func companionVarieties(named name: String) -> [Variety] {
        guard let target = loadVarieties().first(where: { $0.name == name }) else {
            return []
        }
        
        let antagonists = Set(target.antagonists)
        return loadVarieties().filter { $0.name != name && !antagonists.contains($0.name) }
    }
    
    /// Lookup a variety by its barcode.
    static func lookupByBarcode(_ barcode: String) -> Variety? {
        return loadVarieties().first(where: { $0.barcode == barcode })
    }

    // MARK: - Demo data (used when JSON file is missing)
    
    private static var demoVarieties: [Variety] {
        [
            Variety(
                name: "Tomato 'Celebrity'",
                family: "Solanaceae",
                category: .nightshade,
                spacing: 60,
                depth: 3,
                daysToMature: 75,
                sunReq: .fullSun,
                moistureReq: .moderate,
                frostTolerance: .tender,
                waterNeed: .high,
                sowOffset: 60,
                transplantOffset: 0,
                harvestWindow: 30,
                companions: ["Basil", "Marigold", "Carrot", "Onion"],
                antagonists: ["Fennel", "Cabbage", "Potato"],
                sfgPerSquare: 1,
                matureHeight: 180,
                matureWidth: 90
            ),
            Variety(
                name: "Lettuce 'Oakleaf'",
                family: "Asteraceae",
                category: .leafyGreen,
                spacing: 20,
                depth: 0.5,
                daysToMature: 45,
                sunReq: .partialShade,
                moistureReq: .moderate,
                frostTolerance: .lightFrost,
                waterNeed: .moderate,
                sowOffset: 30,
                transplantOffset: 0,
                harvestWindow: 21,
                companions: ["Carrot", "Radish", "Strawberry"],
                antagonists: ["Broccoli", "Cauliflower"],
                sfgPerSquare: 9,
                matureHeight: 25,
                matureWidth: 20
            ),
            Variety(
                name: "Basil 'Genovese'",
                family: "Lamiaceae",
                category: .herb,
                spacing: 30,
                depth: 0.5,
                daysToMature: 60,
                sunReq: .fullSun,
                moistureReq: .moderate,
                frostTolerance: .tender,
                waterNeed: .moderate,
                sowOffset: 45,
                transplantOffset: 0,
                harvestWindow: 60,
                companions: ["Tomato", "Pepper", "Oregano"],
                antagonists: ["Sage", "Rue"],
                sfgPerSquare: 4,
                matureHeight: 45,
                matureWidth: 30
            ),
            Variety(
                name: "Carrot 'Nantes'",
                family: "Apiaceae",
                category: .root,
                spacing: 5,
                depth: 1,
                daysToMature: 70,
                sunReq: .partialSun,
                moistureReq: .moderate,
                frostTolerance: .moderateFrost,
                waterNeed: .moderate,
                sowOffset: 45,
                transplantOffset: 0,
                harvestWindow: 30,
                companions: ["Lettuce", "Radish", "Pea", "Onion"],
                antagonists: ["Dill", "Potato"],
                sfgPerSquare: 16,
                matureHeight: 30,
                matureWidth: 5
            ),
            Variety(
                name: "Zucchini 'Black Beauty'",
                family: "Cucurbitaceae",
                category: .gourd,
                spacing: 120,
                depth: 2,
                daysToMature: 50,
                sunReq: .fullSun,
                moistureReq: .high,
                frostTolerance: .tender,
                waterNeed: .high,
                sowOffset: 30,
                transplantOffset: 0,
                harvestWindow: 14,
                companions: ["Corn", "Bean", "Squash", "Marigold"],
                antagonists: ["Potato", "Rue"],
                sfgPerSquare: 1,
                matureHeight: 60,
                matureWidth: 120
            ),
            Variety(
                name: "Cucumber 'Marketmore'",
                family: "Cucurbitaceae",
                category: .gourd,
                spacing: 45,
                depth: 2,
                daysToMature: 55,
                sunReq: .fullSun,
                moistureReq: .high,
                frostTolerance: .tender,
                waterNeed: .high,
                sowOffset: 30,
                transplantOffset: 0,
                harvestWindow: 21,
                companions: ["Bean", "Corn", "Pea", "Sunflower"],
                antagonists: ["Potato", "Sage"],
                sfgPerSquare: 4,
                matureHeight: 120,
                matureWidth: 45
            ),
            Variety(
                name: "Basil 'Thai'",
                family: "Lamiaceae",
                category: .herb,
                spacing: 30,
                depth: 0.5,
                daysToMature: 60,
                sunReq: .fullSun,
                moistureReq: .moderate,
                frostTolerance: .tender,
                waterNeed: .moderate,
                sowOffset: 45,
                transplantOffset: 0,
                harvestWindow: 45,
                companions: ["Tomato", "Pepper", "Basil"],
                antagonists: ["Sage", "Rue"],
                sfgPerSquare: 4,
                matureHeight: 40,
                matureWidth: 30
            ),
            Variety(
                name: "Pea 'Sugar Snap'",
                family: "Fabaceae",
                category: .legume,
                spacing: 5,
                depth: 2,
                daysToMature: 60,
                sunReq: .partialSun,
                moistureReq: .moderate,
                frostTolerance: .lightFrost,
                waterNeed: .moderate,
                sowOffset: 45,
                transplantOffset: 0,
                harvestWindow: 14,
                companions: ["Carrot", "Corn", "Radish", "Turnip"],
                antagonists: ["Onion", "Garlic"],
                sfgPerSquare: 16,
                matureHeight: 120,
                matureWidth: 5
            ),
            Variety(
                name: "Radish 'French Breakfast'",
                family: "Brassicaceae",
                category: .root,
                spacing: 3,
                depth: 1,
                daysToMature: 25,
                sunReq: .partialSun,
                moistureReq: .moderate,
                frostTolerance: .moderateFrost,
                waterNeed: .moderate,
                sowOffset: 30,
                transplantOffset: 0,
                harvestWindow: 14,
                companions: ["Lettuce", "Pea", "Carrot"],
                antagonists: ["Potato"],
                sfgPerSquare: 16,
                matureHeight: 15,
                matureWidth: 3
            ),
            Variety(
                name: "Onion 'Red Wine'",
                family: "Alliaceae",
                category: .allium,
                spacing: 10,
                depth: 1,
                daysToMature: 100,
                sunReq: .fullSun,
                moistureReq: .low,
                frostTolerance: .moderateFrost,
                waterNeed: .low,
                sowOffset: 90,
                transplantOffset: 0,
                harvestWindow: 30,
                companions: ["Carrot", "Beet", "Lettuce"],
                antagonists: ["Bean", "Pea", "Asparagus"],
                sfgPerSquare: 16,
                matureHeight: 30,
                matureWidth: 10
            )
        ]
    }
}

/// JSON wrapper for the bundled plant database.
struct VarietyListWrapper: Codable {
    let varieties: [Variety]
    let version: String
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case varieties = "varieties"
        case version = "version"
        case source = "source"
    }
}
