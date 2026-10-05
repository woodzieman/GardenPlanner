import Foundation

/// Free, keyless weather API wrapper (Open-Meteo).
/// No API key required, no server — pure client-side.
/// Provides forecasts + frost alerts + planting window calculations.

struct WeatherService {
    
    struct Forecast {
        let temperature: Double       // Celsius
        let precipitation: Double     // mm
        let windSpeed: Double         // km/h
        let humidity: Double          // %
        let sunrise: Date
        let sunset: Date
    }
    
    struct FrostAlert: Identifiable {
        let id = UUID()
        let isFrostRisk: Bool
        let minTemperature: Double
        let alertDate: Date
        let severity: FrostSeverity
    }
    
    enum FrostSeverity {
        case none
        case watch    // temp 0-4°C
        case warning  // temp < 0°C
    }
    
    /// Get a 7-day forecast for coordinates.
    static func forecast(latitude: Double, longitude: Double) async throws -> [Forecast] {
        let query = "daily=temperature_2m_min,temperature_2m_max,precipitation_sum,wind_speed_10m_max,relative_humidity_2m_min,sunrise,sunset&timezone=auto&forecast_days=7"
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&\(query)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let daily = json?["daily"] as? [String: Any],
              let dates = daily["time"] as? [String],
              let temps = daily["temperature_2m_min"] as? [Double],
              let precip = daily["precipitation_sum"] as? [Double],
              let winds = daily["wind_speed_10m_max"] as? [Double],
              let humidities = daily["relative_humidity_2m_min"] as? [Double],
              let sunrises = daily["sunrise"] as? [String],
              let sunsets = daily["sunset"] as? [String]
        else {
            throw WeatherError.invalidResponse
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        var results: [Forecast] = []
        for i in 0..<dates.count
        where i < temps.count && i < precip.count && i < winds.count
            && i < humidities.count && i < sunrises.count && i < sunsets.count {
            guard let sunrise = dateFormatter.date(from: sunrises[i]),
                  let sunset = dateFormatter.date(from: sunsets[i])
            else { continue }
            
            results.append(Forecast(
                temperature: temps[i],
                precipitation: precip[i],
                windSpeed: winds[i],
                humidity: humidities[i],
                sunrise: sunrise,
                sunset: sunset
            ))
        }
        return results
    }
    
    /// Check for frost risk in the next 3 days.
    static func checkFrostRisk(latitude: Double, longitude: Double) async throws -> [FrostAlert] {
        let forecast = try await forecast(latitude: latitude, longitude: longitude)
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return forecast.prefix(3).enumerated()
            .compactMap { index, day in
                guard day.temperature < 4.0 else { return nil }  // only real frost-risk days
                let alertDate = calendar.date(byAdding: .day, value: index, to: today)!
                return FrostAlert(
                    isFrostRisk: true,
                    minTemperature: day.temperature,
                    alertDate: alertDate,
                    severity: day.temperature < 0 ? .warning : .watch
                )
            }
    }
    
    /// Get planting window alerts (when it's time to sow/transplant).
    /// Uses the user's custom frost dates when provided, otherwise the USDA zone approximation.
    static func plantingAlerts(frostDates: (last: String?, first: String?), usdaZone: String = "5", varieties: [Variety]) -> [String] {
        let calendar = Calendar.current
        let today = Date()
        var alerts: [String] = []
        
        let lastFrost = FrostDateService.parseFrostDate(frostDates.last ?? "", calendar: calendar)
            ?? FrostDateService.lastSpringFrostDate(for: usdaZone)
        let firstFrost = FrostDateService.parseFrostDate(frostDates.first ?? "", calendar: calendar)
            ?? FrostDateService.firstFallFrostDate(for: usdaZone)
        
        guard let lastFrost = lastFrost else { return [] }
        
        for variety in varieties {
            let sowWindow = calendar.date(byAdding: .day, value: -variety.sowOffset, to: lastFrost)
            if let sowWindow = sowWindow {
                let daysUntilSow = Int(sowWindow.timeIntervalSince(today).days)
                if daysUntilSow <= 7 && daysUntilSow >= 0 {
                    alerts.append("Time to sow \(variety.name)")
                }
            }
            
            if let firstFrost = firstFrost, variety.frostTolerance == .tender {
                let daysUntilFrost = Int(firstFrost.timeIntervalSince(today).days)
                if daysUntilFrost <= 14 {
                    alerts.append("Bring in \(variety.name) — frost expected soon")
                }
            }
        }
        
        return alerts
    }
}

enum WeatherError: Error {
    case invalidResponse
    case networkError
    case invalidCoordinates
}

// MARK: - Double extension for convenience

extension Double {
    var days: Double { self / 86400.0 }
}
