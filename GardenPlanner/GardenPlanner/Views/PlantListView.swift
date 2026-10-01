import SwiftUI

/// Browse and search the plant database.
/// Filter by category, search by name, view details.

struct PlantListView: View {
    @State private var searchQuery = ""
    @State private var selectedCategory: PlantCategory? = nil
    @State private var showingDetails = false
    @State private var selectedVariety: Variety? = nil
    
    private var filteredVarieties: [Variety] {
        let all = PlantDatabaseService.loadVarieties()
        let searched = searchQuery.isEmpty ? all : PlantDatabaseService.search(query: searchQuery)
        return selectedCategory == nil ? searched : searched.filter { $0.category == selectedCategory }
    }
    
    @State private var isShowingScanner = false
    
    var body: some View {
        NavigationStack {
            List {
                // Search
                Section {
                    TextField("Search plants...", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                }
                
                // Category filter
                Section("Categories") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(nil as PlantCategory?)
                        ForEach(PlantCategory.allCases, id: \.self) { cat in
                            let icon = categoryIcon(cat)
                            Text("\(icon) \(cat.rawValue)").tag(cat as PlantCategory?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Results
                ForEach(filteredVarieties) { variety in
                    NavigationLink {
                        PlantDetailView(variety: variety)
                    } label: {
                        varietyRow(variety)
                    }
                }
            }
            .navigationTitle("Plant Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("Scan Seed", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                SeedScannerView { record in
                    print("Seed record saved: \(record.barcode)")
                }
            }
            .badge(filteredVarieties.count)
        }
    }
    
    private func varietyRow(_ variety: Variety) -> some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(variety.category))
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(variety.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text(variety.family)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    Text("⏱ \(variety.daysToMature)d")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    sunIcon(variety.sunReq)
                        .foregroundStyle(.yellow)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func categoryIcon(_ category: PlantCategory) -> String {
        switch category {
        case .vegetable: return "🥬"
        case .herb: return "🌿"
        case .flower: return "🌸"
        case .fruit: return "🍎"
        case .root: return "🥕"
        case .legume: return "🫘"
        case .gourd: return "🎃"
        case .allium: return "🧅"
        case .brassica: return "🥦"
        case .nightshade: return "🍅"
        case .cucurbit: return "🥒"
        case .leafyGreen: return "🥗"
        case .other: return "🌱"
        }
    }
    
    private func sunIcon(_ sunReq: SunRequirement) -> Image {
        switch sunReq {
        case .fullSun: return Image(systemName: "sun.max.fill")
        case .partialSun: return Image(systemName: "sun.haze.fill")
        case .partialShade: return Image(systemName: "cloud.sun.fill")
        case .fullShade: return Image(systemName: "cloud.fill")
        }
    }
}
