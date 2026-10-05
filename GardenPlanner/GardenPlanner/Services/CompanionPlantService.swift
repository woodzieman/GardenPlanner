import Foundation

/// Companion planting analysis.
/// Checks plant pairings against the variety database for
//  good neighbors (companions) and bad neighbors (antagonists).

struct CompanionPlantService {
    
    /// Get all compatibility info for a plant name.
    static func compatibility(for plantName: String) -> (companions: [String], antagonists: [String]) {
        let varieties = PlantDatabaseService.loadVarieties()
        guard let plant = varieties.first(where: { $0.name == plantName }) else {
            return ([], [])
        }
        return (plant.companions, plant.antagonists)
    }
    
    /// Get all plants that are compatible with the given variety.
    static func compatiblePlants(named name: String) -> [Variety] {
        let (companions, antagonists) = compatibility(for: name)
        let allVarieties = PlantDatabaseService.loadVarieties()
        
        return allVarieties.filter { variety in
            variety.name != name &&
            !antagonists.contains(variety.name) &&
            companions.contains(variety.name)
        }
    }
    
    /// Get all plants that conflict with the given variety.
    static func conflictingPlants(named name: String) -> [Variety] {
        let (_, antagonists) = compatibility(for: name)
        let allVarieties = PlantDatabaseService.loadVarieties()
        
        return allVarieties.filter { variety in
            variety.name != name && antagonists.contains(variety.name)
        }
    }
    
    /// Check if two plant names are compatible.
    static func isCompatible(_ plant1: String, with plant2: String) -> Bool {
        let (_, antagonists) = compatibility(for: plant1)
        return !antagonists.contains(plant2)
    }
    
    /// Get all conflicts between a list of plant names.
    static func conflicts(among plantNames: [String]) -> [(String, String)] {
        var conflicts: [(String, String)] = []
        
        for i in 0..<plantNames.count {
            for j in (i+1)..<plantNames.count {
                if !isCompatible(plantNames[i], with: plantNames[j]) {
                    conflicts.append((plantNames[i], plantNames[j]))
                }
            }
        }
        
        return conflicts
    }
    
    /// Suggest plants to add next to a chosen plant (compatible, not conflicting with existing).
    static func suggestions(
        beside existingPlants: [String],
        excluding: [String] = []
    ) -> [Variety] {
        let allVarieties = PlantDatabaseService.loadVarieties()
        
        return allVarieties.filter { variety in
            let name = variety.name
            guard !existingPlants.contains(name) && !excluding.contains(name) else {
                return false
            }
            
            // Must be a companion of at least one existing plant
            return existingPlants.contains { plantName in
                let (companions, _) = compatibility(for: plantName)
                return companions.contains(name)
            }
        }
    }
}
