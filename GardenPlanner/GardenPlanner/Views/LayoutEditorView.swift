import SwiftUI
import SwiftData

/// Surface zone editor — paint zones on a map (LiDAR scan or manual).
/// Supports surface type assignment, light/wetness sliders, SFG grid,
//  row spacing, and manual drawing tools.

struct LayoutEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Garden.name) private var gardens: [Garden]
    
    @State private var selectedGarden: Garden?
    @State private var editingZone: SurfaceZone?
    @State private var showingZoneEditor = false
    @State private var showingManualEditor = false
    @State private var showingScanner = false
    
    var body: some View {
        NavigationStack {
            if let garden = selectedGarden ?? gardens.first {
                gardenEditor(garden)
                    .onAppear { selectedGarden = garden }
            } else {
                ContentUnavailableView(
                    "No garden selected",
                    systemImage: "leaf.fill",
                    description: Text("Create a garden or select one from the Gardens tab.")
                )
            }
        }
    }
    
    private func gardenEditor(_ garden: Garden) -> some View {
        List {
            // Surface zones section
            Section("Surface Zones") {
                if garden.surfaceZones.isEmpty {
                    Text("No zones yet. Start with a scan or add manually.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(garden.surfaceZones) { zone in
                        zoneRow(zone, in: garden)
                            .onTapGesture {
                                editingZone = zone
                                showingZoneEditor = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let zone = garden.surfaceZones[safe: index] {
                                modelContext.delete(zone)
                            }
                        }
                    }
                }
                
                // Add zone buttons
                Button {
                    showingManualEditor = true
                } label: {
                    Label("Add Zone Manually", systemImage: "plus.circle")
                }
                
                #if os(iOS)
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan with LiDAR", systemImage: "scan")
                        .foregroundStyle(.blue)
                }
                #endif
            }
            
            // Plant instances section
            Section("Planted") {
                if garden.plantInstances.isEmpty {
                    Text("No plants placed yet. Tap a zone to plant.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(garden.plantInstances) { plant in
                        HStack {
                            Text(plant.variety?.name ?? plant.varietyName)
                            Spacer()
                            
                            if plant.isWarning {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                            
                            Text(plant.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Garden info
            Section("Garden Info") {
                Text("Total area: \(String(format: "%.1f", garden.totalArea)) m²")
                Text("Plantable zones: \(garden.plantableZoneCount)")
                Text("Plants placed: \(garden.plantCount)")
            }
        }
        .sheet(isPresented: $showingZoneEditor) {
            SurfaceZoneEditorView(zone: editingZone, garden: garden)
        }
        .sheet(isPresented: $showingManualEditor) {
            ManualMapEditorView(garden: garden)
        }
        .sheet(isPresented: $showingScanner) {
            ScanCaptureView()
        }
    }
    
    private func zoneRow(_ zone: SurfaceZone, in garden: Garden) -> some View {
        HStack(spacing: 8) {
            Image(systemName: zoneTypeIcon(zone.surfaceType))
                .font(.title3)
                .foregroundStyle(Color(hexString: zone.surfaceType.colorHex))
            
            Text(zone.name ?? zone.surfaceType.rawValue)
                .font(.body)
            
            Spacer()
            
            // Show a warning badge if any plant in this zone has light/wetness issues.
            let warnings = garden.plantInstances.filter { $0.zone?.id == zone.id && $0.isWarning }.count
            if warnings > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            
            Text("\(String(format: "%.1f", zone.area))m²")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func zoneTypeIcon(_ type: SurfaceZoneType) -> String {
        switch type {
        case .gardenBed: return "leaf.fill"
        case .raisedBed: return "rectangle.on.rectangle"
        case .concrete: return "square.fill"
        case .path: return "square.split.2x2"
        case .lawn: return "mountain.fill"
        case .water: return "water.waves"
        case .other: return "questionmark.circle.fill"
        }
    }
}

