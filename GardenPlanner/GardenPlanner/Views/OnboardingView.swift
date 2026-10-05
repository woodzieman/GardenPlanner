import SwiftUI
import SwiftData
import ARKit

/// Multi-step onboarding flow: location → USDA zone → frost dates → units → LiDAR check.
/// This is the first thing users see. It configures the Profile and Garden defaults.

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var step = 0
    @State private var location = ""
    @State private var zipCode = ""
    @State private var usdaZone = "5"
    @State private var lastFrostDate = "Apr 15"
    @State private var firstFrostDate = "Oct 15"
    @State private var units: UnitSystem = .metric
    @State private var gardenName = ""
    
    private let steps = ["Location", "Frost Dates", "Preferences", "Garden"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Progress
                Section {
                    ProgressView(value: Double(step), total: Double(steps.count))
                        .padding(.vertical)
                }
                
                switch step {
                case 0: locationStep
                case 1: frostDateStep
                case 2: preferencesStep
                case 3: gardenStep
                default: locationStep
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if step < steps.count - 1 {
                        Button("Next") { step += 1 }
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                            hasCompletedOnboarding = true
                        }
                        .bold()
                    }
                }
            }
        }
    }
    
    // MARK: - Steps
    
    private var locationStep: some View {
        Section("Location") {
            TextField("City or ZIP code", text: $zipCode)
            
            if !zipCode.isEmpty {
                Text("USDA Zone \(usdaZone)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            TextField("Or enter USDA Zone (1-10)", text: $usdaZone)
                .keyboardType(.numberPad)
            
            Text("Your USDA zone determines planting dates for all your crops.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var frostDateStep: some View {
        Section("Frost Dates") {
            TextField("Last spring frost (e.g. Apr 15)", text: $lastFrostDate)
            
            TextField("First fall frost (e.g. Oct 15)", text: $firstFrostDate)
            
            Text("Frost dates are used to calculate when to sow, transplant, and harvest. You can always change them later.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            Text("LiDAR Capability Check:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(checkLiDARStatus())
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }
    
    private var preferencesStep: some View {
        Section("Preferences") {
            Picker("Units", selection: $units) {
                Text("Metric (meters, centimeters)").tag(UnitSystem.metric)
                Text("Imperial (feet, inches)").tag(UnitSystem.imperial)
            }
            
            Text("This affects all measurements throughout the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var gardenStep: some View {
        Section("Your First Garden") {
            TextField("Garden name", text: $gardenName)
                .textCase(.none)
                .textInputAutocapitalization(.words)
            
            Text("This garden will be your default. You can create additional gardens later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func completeOnboarding() {
        // Reuse an existing garden if there is one (e.g. onboarding re-run after
        // a data reset edge case); otherwise create the default garden.
        let garden: Garden
        if let existing = try? modelContext.fetch(FetchDescriptor<Garden>(
            sortBy: [SortDescriptor(\Garden.createdDate)]
        )).first {
            garden = existing
        } else {
            garden = Garden(name: gardenName.isEmpty ? "My Garden" : gardenName)
            modelContext.insert(garden)
        }
        
        guard let profile = garden.profile else { return }
        profile.location = zipCode.isEmpty ? "Auto" : zipCode
        profile.usdaZone = usdaZone
        profile.lastFrostDate = lastFrostDate
        profile.firstFrostDate = firstFrostDate
        profile.units = units
        #if os(iOS)
        profile.hasLiDAR = ARWorldTrackingConfiguration.isSupported
            && ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth])
        #endif
        
        try? modelContext.save()
    }
    
    private func checkLiDARStatus() -> String {
        #if os(iOS)
        if ARWorldTrackingConfiguration.isSupported
            && ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth]) {
            return "✅ Depth scanning available — LiDAR scan unlocked (LiDAR on Pro models, stereo elsewhere)"
        } else if ARWorldTrackingConfiguration.isSupported {
            return "⚠ AR tracking available, but no scene depth — limited scan"
        } else {
            return "❌ No AR support on this device — manual map editor is the core path"
        }
        #else
        return "ℹ️ Running on simulator — no device check available"
        #endif
    }
}
