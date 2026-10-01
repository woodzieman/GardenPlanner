import SwiftUI
import SwiftData

/// Planting calendar computed from profile + variety.
/// Shows sowing, transplanting, and harvest dates as a Gantt-style timeline.
/// Never stores dates — always computed from current profile + variety.

struct PlantingCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Garden.name) private var gardens: [Garden]
    
    let varieties: [Variety] = PlantDatabaseService.loadVarieties()
    
    init() {}
    
    var body: some View {
        NavigationStack {
            if let garden = gardens.first {
                calendarList(garden)
            } else {
                ContentUnavailableView(
                    "No garden",
                    systemImage: "calendar",
                    description: Text("Create a garden to see planting dates.")
                )
            }
        }
        .navigationTitle("Planting Calendar")
    }
    
    private func calendarList(_ garden: Garden) -> some View {
        List {
            Section("This Season") {
                ForEach(varieties) { variety in
                    plantingRow(variety, garden: garden)
                }
            }
            
            Section("Quick Reference") {
                ForEach(companionPairs, id: \.0) { pair in
                    HStack {
                        Text(pair.0)
                        Spacer()
                        Text(pair.1)
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func plantingRow(_ variety: Variety, garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(variety.name)
                .font(.body)
                .fontWeight(.medium)
            
            // Timeline bar
            HStack(spacing: 4) {
                timelineSegment(
                    label: "Sow",
                    days: -variety.sowOffset,
                    totalDays: variety.daysToMature,
                    color: .blue
                )
                
                timelineSegment(
                    label: "Transplant",
                    days: -variety.transplantOffset,
                    totalDays: variety.daysToMature,
                    color: .orange
                )
                
                timelineSegment(
                    label: "Harvest",
                    days: variety.daysToMature,
                    totalDays: variety.daysToMature,
                    color: .green
                )
            }
            .frame(height: 20)
            
            // Dates
            HStack(spacing: 12) {
                Text("🌱 \(variety.sowOffset)d before")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                
                Text("🌿 \(variety.transplantOffset)d before")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Text("🥬 \(variety.daysToMature)d total")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func timelineSegment(label: String, days: Int, totalDays: Int, color: Color) -> some View {
        let fraction = totalDays > 0 ? Double(abs(days)) / Double(totalDays) : 0.0
        let width = max(20.0, fraction * 100)
        
        return VStack(spacing: 2) {
            Capsule()
                .fill(color.opacity(0.7))
                .frame(width: width, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
    
    private var companionPairs: [(String, String)] {
        // Common companion pairs from the database
        [
            ("Tomato", "Basil"),
            ("Tomato", "Marigold"),
            ("Corn", "Bean"),
            ("Corn", "Squash"),
            ("Carrot", "Onion"),
            ("Lettuce", "Radish"),
            ("Pea", "Carrot"),
            ("Cucumber", "Bean"),
            ("Strawberry", "Borage"),
            ("Pepper", "Basil")
        ]
    }
}
