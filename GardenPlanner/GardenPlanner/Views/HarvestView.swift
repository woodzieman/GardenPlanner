import SwiftUI
import SwiftData

/// Harvest view — yield logs, season-over-season analytics.
/// Records what was harvested, when, and how much.
struct HarvestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HarvestRecord.harvestDate) private var harvests: [HarvestRecord]
    @Query(sort: \Garden.name) private var gardens: [Garden]
    @State private var showingNewHarvest = false
    
    private var currentSeason: String {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 4 && month <= 9 ? "Spring-Summer 2026" : "Fall-Winter 2025-26"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Summary stats
                summarySection
                
                // Harvest logs
                Section("Harvest Records (\(harvests.count))") {
                    ForEach(harvests) { record in
                        harvestRow(record)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let record = harvests[safe: index] {
                                modelContext.delete(record)
                            }
                        }
                    }
                }
                
                // Season analytics
                seasonAnalyticsSection
            }
            .navigationTitle("Harvest")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingNewHarvest = true
                    } label: {
                        Label("Log Harvest", systemImage: "leaf")
                    }
                }
            }
            .sheet(isPresented: $showingNewHarvest) {
                NewHarvestSheet()
            }
        }
    }
    
    private var summarySection: some View {
        let totalYield = harvests.reduce(0) { $0 + $1.quantity }
        let totalEntries = harvests.count
        let uniquePlants = Set(harvests.map { $0.plantName }).count
        
        return Section("Season Summary") {
            HStack {
                Text("Total Records")
                Spacer()
                Text("\(totalEntries)")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Total Yield")
                Spacer()
                Text("\(totalYield) units")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Plant Types Harvested")
                Spacer()
                Text("\(uniquePlants)")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var seasonAnalyticsSection: some View {
        let topHarvested = topHarvestedPlants()
        if !topHarvested.isEmpty {
        Section("Top Harvested") {
            ForEach(Array(topHarvested.enumerated()), id: \.offset) { index, plant in
                HStack {
                    Text("\(index + 1). \(plant.name)")
                    Spacer()
                    Text("\(plant.total) units")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
        }
        }
    }
    
    private func harvestRow(_ record: HarvestRecord) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.plantName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text("📅 \(record.harvestDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("· \(record.quantity) units")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    if let notes = record.notes, !notes.isEmpty {
                        Text("· \(notes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func topHarvestedPlants() -> [(name: String, total: Int)] {
        let grouped = Dictionary(grouping: harvests) { $0.plantName }
        return grouped.map { name, records in
            (name: name, total: records.reduce(0) { $0 + $1.quantity })
        }
        .sorted { $0.total > $1.total }
        .prefix(5)
        .map { ($0.name, $0.total) }
    }
}

// MARK: - New Harvest Sheet

struct NewHarvestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var plantName = ""
    @State private var quantity = 1
    @State private var harvestDate = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Harvest Details") {
                    TextField("Plant name (e.g., 'Tomato Celebrity')", text: $plantName)
                    
                    Stepper("Quantity: \(quantity) units", value: $quantity, in: 1...1000)
                    
                    DatePicker("Harvest date", selection: $harvestDate, displayedComponents: [.date])
                    
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Log Harvest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHarvest() }
                        .disabled(plantName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveHarvest() {
        let record = HarvestRecord(
            plantName: plantName,
            quantity: quantity,
            harvestDate: harvestDate,
            notes: notes
        )
        modelContext.insert(record)
        
        plantName = ""
        quantity = 1
        notes = ""
        dismiss()
    }
}

