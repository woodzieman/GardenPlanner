import SwiftUI

/// Track view — navigation hub for Calendar, Tasks, Harvest, Journal, and Weather.
/// All sub-features for tracking your growing season.
struct TrackView: View {
    var body: some View {
        NavigationStack {
            List {
                // Calendar
                NavigationLink {
                    PlantingCalendarView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Planting Calendar")
                                .font(.body)
                            Text("Sow, transplant, and harvest dates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Tasks
                NavigationLink {
                    TasksView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tasks")
                                .font(.body)
                            Text("Weekly to-do list from your calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Weather
                NavigationLink {
                    WeatherView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.sun")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weather")
                                .font(.body)
                            Text("7-day forecast + frost alerts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Harvest
                NavigationLink {
                    HarvestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Harvest")
                                .font(.body)
                            Text("Log yields and track seasonal analytics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Journal
                NavigationLink {
                    JournalView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "journal.text")
                            .font(.title3)
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Journal")
                                .font(.body)
                            Text("Per-plant notes and season archive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Track Season")
        }
    }
}
