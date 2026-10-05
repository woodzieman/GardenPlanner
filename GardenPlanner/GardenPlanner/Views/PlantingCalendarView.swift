import SwiftUI
import SwiftData

/// Planting calendar computed from profile + variety.
/// Shows sowing, transplanting, and harvest dates as a timeline.
/// Dates are never stored — always computed from the garden's profile
/// (custom frost dates, falling back to USDA-zone averages) + variety data.

struct PlantingCalendarView: View {
    @Query(sort: \Garden.name) private var gardens: [Garden]
    
    private let varieties: [Variety] = PlantDatabaseService.loadVarieties()
    
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
        let profile = garden.profile
        
        return List {
            // Frost-date basis (custom values win; zone is the fallback)
            Section {
                Text("Last frost: \(profile?.lastFrostDate ?? "—") · First frost: \(profile?.firstFrostDate ?? "—") · USDA Zone \(profile?.usdaZone ?? "5")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            footer: {
                Text("Dates are computed from your frost dates. Change them in Settings → Edit Profile.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Section("This Season") {
                ForEach(varieties) { variety in
                    plantingRow(variety, garden: garden)
                }
            }
            
            Section("Companion Quick Reference") {
                ForEach(Array(companionPairs.enumerated()), id: \.offset) { _, pair in
                    HStack {
                        Text(pair.0)
                        Spacer()
                        Text("+ \(pair.1)")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func plantingRow(_ variety: Variety, garden: Garden) -> some View {
        let profile = garden.profile
        let window = FrostDateService.plantingWindow(
            for: variety,
            usdaZone: profile?.usdaZone ?? "5",
            lastFrost: profile?.lastFrostDate,
            firstFrost: profile?.firstFrostDate
        )
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(variety.name)
                .font(.body)
                .fontWeight(.medium)
            
            // Timeline bar
            HStack(spacing: 4) {
                timelineSegment(
                    label: "Sow",
                    days: variety.sowOffset,
                    totalDays: variety.daysToMature,
                    color: .blue
                )
                
                timelineSegment(
                    label: "Transplant",
                    days: max(1, variety.transplantOffset),
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
            .frame(height: 24)
            
            // Actual calendar dates
            HStack(spacing: 12) {
                Text("🌱 \(window.sowDateString)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                
                Text("🌿 \(window.transplantDateString)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Text("🥬 \(window.harvestDateString)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func timelineSegment(label: String, days: Int, totalDays: Int, color: Color) -> some View {
        let fraction = totalDays > 0 ? min(1.0, Double(days) / Double(totalDays)) : 0.0
        let width = max(24.0, fraction * 110)
        
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
        // Common companion pairs
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
