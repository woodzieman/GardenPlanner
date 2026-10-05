import SwiftUI

/// Detailed view for a single plant variety.
/// Shows all metadata: spacing, depth, sun, moisture, frost tolerance,
//  water needs, planting dates, companions, antagonists, SFG.

struct PlantDetailView: View {
    let variety: Variety
    @State private var showCompanions = false
    @State private var showAntagonists = false
    
    var body: some View {
        List {
            // Header info
            Section("Details") {
                detailRow("Family", variety.family)
                detailRow("Category", variety.category.rawValue)
                detailRow("Days to Mature", "\(variety.daysToMature) days")
                detailRow("Spacing", spacingString)
                detailRow("Planting Depth", "\(variety.depth) cm")
                detailRow("Mature Height", heightString)
                detailRow("Mature Width", widthString)
                detailRow("SFG per Square", "\(variety.sfgPerSquare)")
                
                if let barcode = variety.barcode {
                    HStack {
                        Text("Barcode")
                        Spacer()
                        Text(barcode)
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Environment
            Section("Environment") {
                HStack {
                    Text("Sun Requirement")
                    Spacer()
                    sunRequirementBadge
                }
                
                HStack {
                    Text("Moisture")
                    Spacer()
                    Text(variety.moistureReq.rawValue)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Text("Frost Tolerance")
                    Spacer()
                    Text(variety.frostTolerance.rawValue.capitalized)
                        .foregroundStyle(.orange)
                }
                
                HStack {
                    Text("Water Needs")
                    Spacer()
                    Text(variety.waterNeed.displayValue)
                        .foregroundStyle(.blue)
                }
            }
            
            // Companion planting
            Section("Companion Planting") {
                Button {
                    showCompanions = true
                } label: {
                    Text("Good Neighbors (\(companionCount))")
                        .foregroundStyle(.green)
                }
                
                Button {
                    showAntagonists = true
                } label: {
                    Text("Bad Neighbors (\(antagonistCount))")
                        .foregroundStyle(.red)
                }
            }
            
            // Planting guidance
            Section("Planting Guide") {
                Text("Sow indoors \(variety.sowOffset) days before last frost")
                    .font(.caption)
                
                Text("Transplant \(variety.transplantOffset) days before harvest")
                    .font(.caption)
                
                if let harvestText = variety.harvestWindowText {
                    Text("Harvest window: \(harvestText)")
                        .font(.caption)
                } else {
                    Text("Harvest window: \(variety.harvestWindow) days")
                        .font(.caption)
                }
            }
        }
        .navigationTitle(variety.name)
        .sheet(isPresented: $showCompanions) {
            CompanionListSheet(
                title: "Good Neighbors",
                plants: PlantDatabaseService.loadVarieties().filter { variety.companions.contains($0.name) }
            )
        }
        .sheet(isPresented: $showAntagonists) {
            CompanionListSheet(
                title: "Bad Neighbors",
                plants: PlantDatabaseService.loadVarieties().filter { variety.antagonists.contains($0.name) }
            )
        }
    }
    
    // MARK: - Computed
    
    private var companionCount: Int {
        let names = Set(variety.companions)
        return PlantDatabaseService.loadVarieties().filter { names.contains($0.name) }.count
    }
    
    private var antagonistCount: Int {
        let names = Set(variety.antagonists)
        return PlantDatabaseService.loadVarieties().filter { names.contains($0.name) }.count
    }
    
    private var spacingString: String {
        if variety.spacing < 15 {
            return "\(variety.spacing) cm"
        } else {
            return "\(String(format: "%.0f", variety.spacing / 2.54)) in"
        }
    }
    
    private var heightString: String {
        guard variety.matureHeight > 0 else { return "—" }
        if variety.matureHeight < 30 {
            return "\(variety.matureHeight) cm"
        } else {
            return "\(String(format: "%.1f", variety.matureHeight / 30.48)) ft"
        }
    }
    
    private var widthString: String {
        guard variety.matureWidth > 0 else { return "—" }
        if variety.matureWidth < 15 {
            return "\(variety.matureWidth) cm"
        } else {
            return "\(String(format: "%.1f", variety.matureWidth / 2.54)) in"
        }
    }
    
    // MARK: - Views
    
    private var sunRequirementBadge: some View {
        Text(variety.sunReq.rawValue)
            .font(.caption)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        variety.sunReq == .fullSun ? Color.yellow.opacity(0.2) :
                        variety.sunReq == .partialSun ? Color.orange.opacity(0.2) :
                        Color.gray.opacity(0.2)
                    )
            )
            .foregroundStyle(variety.sunReq == .fullSun ? .yellow :
                              variety.sunReq == .partialSun ? .orange : .gray)
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Companion List Sheet

struct CompanionListSheet: View {
    let title: String
    let plants: [Variety]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(plants) { plant in
                Text(plant.name)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
