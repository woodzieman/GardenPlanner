import SwiftUI
import SwiftData
import CloudKit
import ARKit

/// Settings view — profile management, garden management, sync, about.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @Query(sort: \Garden.name) private var gardens: [Garden]
    
    @State private var showingEditProfile = false
    @State private var showingManageGardens = false
    @State private var showingDeleteConfirmation = false
    @State private var gardenToDelete: Garden? = nil
    @State private var syncAvailable = false
    @State private var syncInProgress = false
    @State private var syncMessage: String?
    @State private var showingSyncResult = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile section
                Section("Profile") {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.blue)
                            Text("Edit Profile")
                        }
                    }
                    
                    if let garden = gardens.first {
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
                                Text("Last Frost")
                                Spacer()
                                Text(profile.lastFrostDate ?? "—")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("LiDAR Device")
                                Spacer()
                                Text(profile.hasLiDAR ? "Yes" : "No — manual fallback")
                                    .foregroundStyle(profile.hasLiDAR ? .green : .orange)
                            }
                        }
                    }
                }
                
                // Gardens section
                Section("Gardens") {
                    Button {
                        showingManageGardens = true
                    } label: {
                        HStack {
                            Image(systemName: "square.on.square")
                                .foregroundStyle(.green)
                            Text("Manage Gardens (\(gardens.count))")
                        }
                    }
                }
                
                // CloudKit Sync section (opt-in)
                Section("Sync") {
                    HStack {
                        Image(systemName: syncAvailable ? "checkmark.circle.fill" : "cloud.circle")
                            .foregroundStyle(syncAvailable ? .green : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(syncAvailable ? "Sync Ready" : "CloudKit Available")
                            Text("Gardens sync across your devices. Your data stays private.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(syncInProgress ? "Syncing..." : "Sync Now") {
                            Task {
                                await syncNow()
                            }
                        }
                        .disabled(syncInProgress)
                    }
                    .foregroundStyle(syncAvailable ? .primary : .secondary)
                }
                .opacity(syncAvailable ? 1.0 : 0.5)
                
                // App info
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0-beta")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Plant Database")
                        Spacer()
                        Text("121 plants (v2.0.0-beta)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Free Forever")
                        Spacer()
                        Text("No ads · No paywall · No accounts")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                }
                
                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset App Data")
                        }
                    }
                }
                .foregroundStyle(.red)
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    syncAvailable = await CloudKitSyncService().isAvailable()
                    // Keep the stored LiDAR flag in sync with this device (it's a
                    // device property, not a garden property).
                    if let profile = gardens.first?.profile, profile.hasLiDAR != Self.isSceneDepthAvailable {
                        profile.hasLiDAR = Self.isSceneDepthAvailable
                        try? modelContext.save()
                    }
                }
            }
            .alert(
                "Sync",
                isPresented: $showingSyncResult
            ) {
                Button("OK") { syncMessage = nil }
            } message: {
                Text(syncMessage ?? "")
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet()
            }
            .sheet(isPresented: $showingManageGardens) {
                ManageGardensSheet(gardens: gardens)
            }
            .confirmationDialog(
                "Reset all app data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will delete all gardens, zones, plantings, and records. This cannot be undone.")
            }
        }
    }
    
    private func syncNow() async {
        syncInProgress = true
        defer { syncInProgress = false }
        
        do {
            let service = CloudKitSyncService()
            try await service.setupAccount()
            
            // Push every local garden up.
            let localGardens = try modelContext.fetch(FetchDescriptor<Garden>())
            for garden in localGardens {
                try await service.saveGarden(garden)
            }
            
            // Import remote gardens that don't exist locally (by id).
            let localIDs = Set(localGardens.map(\.id))
            let remoteGardens = try await service.loadGardens()
            let newCount = remoteGardens.filter { !localIDs.contains($0.id) }.count
            for garden in remoteGardens where !localIDs.contains(garden.id) {
                modelContext.insert(garden)
            }
            try modelContext.save()
            
            syncMessage = newCount > 0
                ? "Synced \(localGardens.count) garden(s) and imported \(newCount) from iCloud."
                : "Synced \(localGardens.count) garden(s) — everything is up to date."
            showingSyncResult = true
        } catch {
            syncMessage = error.localizedDescription
            showingSyncResult = true
        }
    }
    
    /// Live device check for scene-depth (LiDAR/stereo) capture support.
    static var isSceneDepthAvailable: Bool {
        #if os(iOS)
        return ARWorldTrackingConfiguration.isSupported
            && ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth])
        #else
        return false
        #endif
    }
    
    private func deleteAllData() {
        // Gardens cascade to zones/plants/scans; the standalone record types
        // (tasks, journal, harvests, seed scans) must be deleted explicitly.
        deleteAll(Garden.self)
        deleteAll(TaskItem.self)
        deleteAll(JournalEntry.self)
        deleteAll(HarvestRecord.self)
        deleteAll(SeedRecord.self)
        try? modelContext.save()
        
        // Reset onboarding flag so user re-enters onboarding
        hasCompletedOnboarding = false
        
        // Reset app storage
        UserDefaults.standard.removeObject(forKey: "selectedTab")
    }
    
    /// Delete every instance of a model type.
    private func deleteAll<M: PersistentModel>(_ type: M.Type) {
        guard let all = try? modelContext.fetch(FetchDescriptor<M>()) else { return }
        for item in all {
            modelContext.delete(item)
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Garden.name) private var gardens: [Garden]
    
    @State private var location = ""
    @State private var usdaZone = "5"
    @State private var lastFrostDate = "Apr 15"
    @State private var firstFrostDate = "Oct 15"
    @State private var householdSize = 1
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Location (city or ZIP)", text: $location)
                    TextField("USDA Growing Zone (1-10)", text: $usdaZone)
                        .keyboardType(.numberPad)
                    
                    TextField("Last Spring Frost (MM DD)", text: $lastFrostDate)
                    TextField("First Fall Frost (MM DD)", text: $firstFrostDate)
                    
                    Stepper("Household Size: \(householdSize)", value: $householdSize, in: 1...20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let garden = gardens.first, let profile = garden.profile {
                    location = profile.location ?? ""
                    usdaZone = profile.usdaZone
                    lastFrostDate = profile.lastFrostDate ?? "Apr 15"
                    firstFrostDate = profile.firstFrostDate ?? "Oct 15"
                    householdSize = profile.householdSize
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let garden = gardens.first else { return }
        garden.profile?.location = location
        garden.profile?.usdaZone = usdaZone
        garden.profile?.lastFrostDate = lastFrostDate
        garden.profile?.firstFrostDate = firstFrostDate
        garden.profile?.householdSize = householdSize
        dismiss()
    }
}

// MARK: - Manage Gardens Sheet

struct ManageGardensSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let gardens: [Garden]
    @State private var gardenToDelete: Garden? = nil
    @State private var showingDelete = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(gardens) { garden in
                    HStack {
                        Text(garden.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(garden.surfaceZones.count) zones · \(garden.plantInstances.count) plants")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        gardenToDelete = garden
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if let garden = gardens[safe: index] {
                            modelContext.delete(garden)
                        }
                    }
                }
            }
            .navigationTitle("Manage Gardens")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Delete Garden?", isPresented: Binding(
            get: { gardenToDelete != nil },
            set: { if !$0 { gardenToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let garden = gardenToDelete {
                    modelContext.delete(garden)
                    gardenToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                gardenToDelete = nil
            }
        }
    }
}

