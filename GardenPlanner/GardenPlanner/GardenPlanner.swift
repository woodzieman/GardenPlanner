import SwiftUI
import SwiftData
import ARKit

@main
struct GardenPlannerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    appState.checkLiDARCapability()
                }
        }
        .modelContainer(for: [
            Garden.self,
            SurfaceZone.self,
            PlantInstance.self,
            Scan.self,
            SeedRecord.self,
            Profile.self,
            JournalEntry.self,
            TaskItem.self,
            HarvestRecord.self
        ])
    }
}

// MARK: - Root Navigation

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationStack {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab = "garden"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GardenListView()
                .tabItem {
                    Label("Gardens", systemImage: "leaf.fill")
                }
                .tag("garden")
            
            PlantListView()
                .tabItem {
                    Label("Plants", systemImage: "seedling.fill")
                }
                .tag("plants")
            
            LayoutEditorView()
                .tabItem {
                    Label("Layout", systemImage: "square.grid.2x2.fill")
                }
                .tag("layout")
            
            TrackView()
                .tabItem {
                    Label("Track", systemImage: "calendar.badge.clock")
                }
                .tag("track")
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag("settings")
        }
    }
}

// MARK: - Garden List View

struct GardenListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Garden.name) private var gardens: [Garden]
    @State private var showingAddGarden = false
    
    var body: some View {
        NavigationStack {
            List {
                if gardens.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No gardens yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to create your first garden")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
                
                ForEach(gardens) { garden in
                    NavigationLink {
                        GardenDetailView(garden: garden)
                    } label: {
                        gardenRow(garden)
                    }
                }
            }
            .navigationTitle("My Gardens")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingAddGarden = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGarden) {
                AddGardenSheet()
            }
        }
    }
    
    private func gardenRow(_ garden: Garden) -> some View {
        HStack(spacing: 12) {
            Image(systemName: garden.surfaceZones.isEmpty ? "square.dashed" : "leaf.fill")
                .font(.title3)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(garden.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if !garden.details.isEmpty {
                    Text(garden.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    Text("\(garden.surfaceZones.count) zones")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    Text(garden.profile?.usdaZone ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let lastScan = garden.lastScanDate {
                Text(lastScan, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Garden Sheet

struct AddGardenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var descriptionText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Garden Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $descriptionText)
                }
                
                Section("Location") {
                    TextField("Address or ZIP code", text: .constant("Auto-detected"))
                        .disabled(true)
                    
                    Text("Location is set during onboarding")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Garden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let garden = Garden(name: name, details: descriptionText)
                        modelContext.insert(garden)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Garden Detail View

struct GardenDetailView: View {
    let garden: Garden
    
    var body: some View {
        List {
            Section("Info") {
                Text(garden.name)
                    .font(.headline)
                
                if !garden.details.isEmpty {
                    Text(garden.details)
                }
                
                if let profile = garden.profile {
                    HStack {
                        Text("USDA Zone")
                        Spacer()
                        Text(profile.usdaZone)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Location")
                        Spacer()
                        Text(profile.location ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Frost date (last)")
                        Spacer()
                        Text(profile.lastFrostDate ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Frost date (first)")
                        Spacer()
                        Text(profile.firstFrostDate ?? "—")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Zones") {
                if garden.surfaceZones.isEmpty {
                    Text("No zones yet. Create a scan or add manually.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(garden.surfaceZones) { zone in
                        HStack {
                            zoneTypeIcon(zone.surfaceType)
                            Text(zone.name ?? "Unnamed")
                            Spacer()
                            Text(zone.surfaceType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Plants") {
                if garden.plantInstances.isEmpty {
                    Text("No plants placed yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(garden.plantInstances) { plant in
                        Text(plant.variety?.name ?? "Unknown plant")
                    }
                }
            }
            
            Section("Scans") {
                if garden.scans.isEmpty {
                    Text("No scans yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(garden.scans) { scan in
                        Text(scan.capturedDate, style: .date)
                    }
                }
            }
        }
        .navigationTitle(garden.name)
    }
    
    private func zoneTypeIcon(_ type: SurfaceZoneType) -> Image {
        switch type {
        case .gardenBed: return Image(systemName: "leaf.fill")
        case .raisedBed: return Image(systemName: "rectangle.on.rectangle")
        case .concrete: return Image(systemName: "square.fill")
        case .path: return Image(systemName: "square.split.2x2")
        case .lawn: return Image(systemName: "mountain.fill")
        case .water: return Image(systemName: "water.waves")
        case .other: return Image(systemName: "questionmark.circle.fill")
        }
    }
}

// MARK: - Supporting Types

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "Metric (m, cm)"
    case imperial = "Imperial (ft, in)"
}

@MainActor
final class AppState: ObservableObject {
    func checkLiDARCapability() {
        #if os(iOS)
        let arSupported = ARWorldTrackingConfiguration.isSupported
        let depthAvailable = arSupported && ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth])
        if depthAvailable {
            print("✅ Scene-depth scanning available (LiDAR on Pro models, stereo elsewhere)")
        } else if arSupported {
            print("⚠ AR supported, but no scene depth")
        } else {
            print("❌ No AR support on this device")
        }
        
        // iPhone Air check
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters) ?? ""
        
        if machine == "iPhone18,1" || machine == "iPhone18,2" {
            print("⚠ iPhone Air detected — single camera, no LiDAR")
            print("   Fallback: manual map editor is the core path")
        }
        #endif
    }
}
