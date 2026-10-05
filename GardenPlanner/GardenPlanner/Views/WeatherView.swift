import SwiftUI
import SwiftData
import CoreLocation

/// Weather view — 7-day forecast with frost alerts and planting window info.
/// Uses Open-Meteo API (free, keyless) — no server required.
struct WeatherView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Garden.name) private var gardens: [Garden]
    @State private var forecast: [WeatherService.Forecast] = []
    @State private var frostAlerts: [WeatherService.FrostAlert] = []
    @State private var loading = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if let garden = gardens.first {
                    weatherContent(garden)
                } else {
                    ContentUnavailableView(
                        "No Garden",
                        systemImage: "cloud.sun",
                        description: Text("Create a garden first to see local weather.")
                    )
                }
            }
            .navigationTitle("Weather")
            .overlay {
                if loading {
                    ProgressView("Loading forecast...")
                }
            }
            .onAppear {
                Task {
                    await loadWeather()
                }
            }
            .refreshable {
                await loadWeather()
            }
        }
    }
    
    private func weatherContent(_ garden: Garden) -> some View {
        List {
            // Frost alerts
            if !frostAlerts.isEmpty {
                Section("Frost Alerts") {
                    ForEach(frostAlerts) { alert in
                        AlertRow(alert: alert)
                    }
                }
            }
            
            if let error = error {
                Section {
                    Label(error, systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            // 7-day forecast
            Section("7-Day Forecast") {
                ForEach(Array(forecast.enumerated()), id: \.offset) { index, day in
                    forecastRow(day, dayIndex: index)
                }
            }
            
            // Planting window
            Section("Planting Window") {
                plantingWindowInfo(garden: garden)
            }
        }
    }
    
    private func forecastRow(_ forecast: WeatherService.Forecast, dayIndex: Int) -> some View {
        let calendar = Calendar.current
        let forecastDate = calendar.date(byAdding: .day, value: dayIndex, to: Date())!
        let dayName = forecastDate.formatted(date: .abbreviated, time: .omitted)
        
        return HStack(spacing: 12) {
            Text(dayName)
                .frame(width: 70, alignment: .leading)
                .font(.body)
            
            // Temperature
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("\(String(format: "%.0f", forecast.temperature))°C")
                    .font(.body)
            }
            .frame(width: 60)
            
            // Precipitation
            Image(systemName: "cloud.rain")
                .foregroundStyle(.blue)
                .font(.caption)
            
            Text("\(String(format: "%.0f", forecast.precipitation))mm")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Wind
            Image(systemName: "wind")
                .foregroundStyle(.secondary)
                .font(.caption)
            
            Text("\(String(format: "%.0f", forecast.windSpeed))km/h")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func plantingWindowInfo(garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Based on your frost dates (USDA Zone \(garden.profile?.usdaZone ?? "5"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Last spring frost: \(garden.profile?.lastFrostDate ?? "Apr 15")")
                .font(.caption)
            
            Text("First fall frost: \(garden.profile?.firstFrostDate ?? "Oct 15")")
                .font(.caption)
            
            Text("Growing season: ~\(growingDays(garden)) days")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
    
    private func growingDays(_ garden: Garden) -> String {
        guard let last = garden.profile?.lastFrostDate,
              let first = garden.profile?.firstFrostDate else { return "—" }
        
        let calendar = Calendar.current
        let lastParsed = FrostDateService.parseFrostDate(last, calendar: calendar)
        let firstParsed = FrostDateService.parseFrostDate(first, calendar: calendar)
        
        guard let lp = lastParsed, let fp = firstParsed, fp > lp else { return "—" }
        let days = Int(fp.timeIntervalSince(lp).days)
        return "\(days)"
    }
    
    private func loadWeather() async {
        loading = true
        error = nil
        defer { loading = false }
        
        guard let garden = gardens.first,
              let profile = garden.profile,
              let location = profile.location,
              !location.isEmpty,
              location.lowercased() != "auto" else {
            error = "Add your city or ZIP in Settings → Edit Profile to get local weather."
            return
        }
        
        let (lat, lon) = await geocodeLocation(location)
        
        do {
            forecast = try await WeatherService.forecast(latitude: lat, longitude: lon)
            frostAlerts = try await WeatherService.checkFrostRisk(latitude: lat, longitude: lon)
        } catch {
            self.error = "Couldn't load the forecast: \(error.localizedDescription)"
        }
    }
    
    /// Geocode the profile location with CLGeocoder (Apple, keyless) —
    /// handles city names and US ZIP codes. Falls back to a small city table,
    /// then a US-center default, so the view never renders empty.
    
    private func geocodeLocation(_ location: String) async -> (Double, Double) {
        // 1. Real geocoding (Apple, keyless) — works for city names and US ZIP codes.
        let placemarks = try? await CLGeocoder().geocodeAddressString(location)
        if let first = placemarks?.first?.location {
            return (first.coordinate.latitude, first.coordinate.longitude)
        }
        
        // 2. Fallback: approximate coordinates for major US cities.
        let cityMap: [String: (Double, Double)] = [
            "kansas": (39.0, -98.5),
            "wichita": (37.7, -97.3),
            "denver": (39.7, -104.9),
            "chicago": (41.9, -87.6),
            "new york": (40.7, -74.0),
            "los angeles": (34.1, -118.2),
            "seattle": (47.6, -122.3),
            "portland": (45.5, -122.7),
            "phoenix": (33.5, -112.1),
            "austin": (30.3, -97.7),
            "dallas": (32.8, -96.8),
            "houston": (29.8, -95.4),
            "atlanta": (33.7, -84.4),
            "miami": (25.8, -80.2),
            "boston": (42.4, -71.1),
            "minneapolis": (45.0, -93.3),
            "milwaukee": (43.0, -87.9),
            "omaha": (41.3, -95.9),
            "lincoln": (40.8, -96.7)
        ]
        
        let lower = location.lowercased()
        for (key, coords) in cityMap {
            if lower.contains(key) {
                return coords
            }
        }
        
        // Default to Kansas (approximate center of US)
        return (39.0, -98.5)
    }
}

// MARK: - Frost Alert Row

struct AlertRow: View {
    let alert: WeatherService.FrostAlert
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: alert.severity == .warning ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                .foregroundStyle(alert.severity == .warning ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.severity == .warning ? "Frost Warning" : "Frost Watch")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Low: \(String(format: "%.0f", alert.minTemperature))°C on \(alert.alertDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
