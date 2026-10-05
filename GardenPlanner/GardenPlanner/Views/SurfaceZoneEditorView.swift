import SwiftUI
import SwiftData

/// Editor for a single surface zone.
/// Allows adjusting: surface type, name, light level, wetness,
//  soil type, wind exposure, elevation, and notes.

struct SurfaceZoneEditorView: View {
    let zone: SurfaceZone?
    let garden: Garden
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var surfaceType: SurfaceZoneType
    @State private var lightLevel: Double
    @State private var wetness: WetnessLevel
    @State private var soilType: SoilType
    @State private var windExposure: WindExposure
    @State private var elevation: Float
    @State private var notes: String
    
    init(zone: SurfaceZone? = nil, garden: Garden) {
        self.zone = zone
        self.garden = garden
        self._name = State(initialValue: zone?.name ?? "")
        self._surfaceType = State(initialValue: zone?.surfaceType ?? .gardenBed)
        self._lightLevel = State(initialValue: zone?.lightLevel ?? 50.0)
        self._wetness = State(initialValue: zone?.wetness ?? .moderate)
        self._soilType = State(initialValue: zone?.soilType ?? .loam)
        self._windExposure = State(initialValue: zone?.windExposure ?? .moderate)
        self._elevation = State(initialValue: zone?.elevation ?? 0.0)
        self._notes = State(initialValue: zone?.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Details") {
                    TextField("Zone name (optional)", text: $name)
                    
                    Picker("Surface type", selection: $surfaceType) {
                        ForEach(SurfaceZoneType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                }
                
                Section("Environment") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Light: \(String(format: "%.0f", lightLevel))%")
                            .font(.caption)
                        
                        Slider(value: $lightLevel, in: 0...100, step: 5) {
                            Text("Light")
                        } minimumValueLabel: {
                            Text("Shade")
                        } maximumValueLabel: {
                            Text("Full Sun")
                        } onEditingChanged: { editing in
                            // Update zone in real-time
                            if let zone = zone {
                                zone.lightLevel = lightLevel
                            }
                        }
                        
                        Text(lightDescription)
                            .font(.caption)
                            .foregroundStyle(lightLevel < 30 ? .blue :
                                             lightLevel > 70 ? .orange : .secondary)
                    }
                    
                    Picker("Wetness", selection: $wetness) {
                        ForEach(WetnessLevel.allCases, id: \.self) { level in
                            Text(level.rawValue)
                        }
                    }
                    
                    Picker("Soil type", selection: $soilType) {
                        ForEach(SoilType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                    
                    Picker("Wind exposure", selection: $windExposure) {
                        ForEach(WindExposure.allCases, id: \.self) { exp in
                            Text(exp.rawValue.capitalized)
                        }
                    }
                    
                    TextField("Elevation (meters above ground)", value: $elevation, format: .number)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes") {
                    TextField("Any notes about this zone?", text: $notes)
                }
            }
            .navigationTitle(zone == nil ? "New Zone" : "Edit Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(zone == nil ? "Create" : "Save") {
                        if let zone = zone {
                            // Update existing zone
                            zone.name = name.isEmpty ? nil : name
                            zone.surfaceType = surfaceType
                            zone.lightLevel = lightLevel
                            zone.wetness = wetness
                            zone.soilType = soilType
                            zone.windExposure = windExposure
                            zone.elevation = elevation
                            zone.notes = notes
                        } else {
                            // Create new zone
                            let newZone = SurfaceZone(
                                name: name.isEmpty ? nil : name,
                                surfaceType: surfaceType,
                                elevation: elevation,
                                lightLevel: lightLevel,
                                wetness: wetness,
                                soilType: soilType,
                                windExposure: windExposure,
                                notes: notes
                            )
                            garden.surfaceZones.append(newZone)
                            modelContext.insert(newZone)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var lightDescription: String {
        switch lightLevel {
        case 0...25: return "🌑 Shade"
        case 26...50: return "🌤 Partial Shade"
        case 51...75: return "☀️ Partial Sun"
        case 76...100: return "☀️ Full Sun"
        default: return "—"
        }
    }
}
