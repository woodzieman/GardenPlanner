import SwiftUI
import SwiftData

/// Journal view — per-plant/zone notes, dated entries, season archive.
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var showingNewEntry = false
    @State private var newDate = Date()
    @State private var newNote = ""
    @State private var selectedPlant = ""
    
    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Journal Entries",
                        systemImage: "journal.text",
                        description: Text("Start recording notes about your garden.")
                    )
                }
                
                ForEach(entries) { entry in
                    JournalEntryRow(entry: entry)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if let entry = entries[safe: index] {
                            modelContext.delete(entry)
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntrySheet(availablePlants: availablePlants())
            }
        }
    }
    
    private func availablePlants() -> [String] {
        guard let garden = try? modelContext.fetch(FetchDescriptor<Garden>()).first else { return [] }
        return garden.plantInstances.map { $0.varietyName }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            date: newDate,
            note: newNote,
            plantName: selectedPlant
        )
        modelContext.insert(entry)
        
        newDate = Date()
        newNote = ""
        selectedPlant = ""
        showingNewEntry = false
    }
}

// MARK: - Journal Entry Row

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.note)
                .font(.body)
            
            HStack(spacing: 6) {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let plantName = entry.plantName, !plantName.isEmpty {
                    Text("· \(plantName)")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                Text("· \(entry.date, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - New Journal Entry Sheet

struct NewJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let availablePlants: [String]
    
    @State private var date = Date()
    @State private var note = ""
    @State private var selectedPlant = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("Note") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
                
                if !availablePlants.isEmpty {
                    Section("Plant") {
                        Picker("Select Plant (optional)", selection: $selectedPlant) {
                            Text("— None —").tag("")
                            ForEach(availablePlants, id: \.self) { plant in
                                Text(plant).tag(plant)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            date: date,
            note: note,
            plantName: selectedPlant.isEmpty ? nil : selectedPlant
        )
        modelContext.insert(entry)
        
        note = ""
        selectedPlant = ""
        isSaving = false
        dismiss()
    }
}


