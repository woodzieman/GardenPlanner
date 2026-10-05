import Foundation

/// Calculates frost dates and planting windows.
/// Uses USDA Zone lookup + NWS frost data or manual overrides.
///
/// Dates are never stored — always computed from:
/// Profile (USDA zone, location) + Variety (daysToMature, sowOffset)

struct FrostDateService {
    
    private static var calendar: Calendar { Calendar.current }
    
    /// Current year, or next year if the seasonal window for this year has already passed.
    private static func springYear() -> Int {
        let cal = calendar
        let now = Date()
        let thisYear = cal.component(.year, from: now)
        // If we're past mid-fall, plan for next spring.
        let seasonEnd = cal.date(from: DateComponents(year: thisYear, month: 10, day: 15))!
        return now > seasonEnd ? thisYear + 1 : thisYear
    }
    
    private static func fallYear() -> Int {
        let cal = calendar
        let now = Date()
        let thisYear = cal.component(.year, from: now)
        // Fall window closes around January 1 — if we're before mid-March, use last fall.
        let seasonEnd = cal.date(from: DateComponents(year: thisYear, month: 3, day: 15))!
        return now < seasonEnd ? thisYear - 1 : thisYear
    }
    
    /// Get the last spring frost date for a USDA zone.
    static func lastSpringFrostDate(for zone: String) -> Date? {
        // Approximate: based on USDA Zone averages (median last frost)
        // Zone 3: May 15, Zone 4: May 1, Zone 5: Apr 15,
        // Zone 6: Apr 1, Zone 7: Mar 15, Zone 8: Mar 1, Zone 9: Feb 15, Zone 10: Feb 1
        let zoneNum = Int(zone) ?? 5
        let baseDate = Calendar.current.date(from: DateComponents(year: springYear(), month: 5, day: 15))!
        let daysOffset = -(zoneNum - 3) * 14  // ~2 weeks per zone
        
        return Calendar.current.date(byAdding: .day, value: daysOffset, to: baseDate)
    }
    
    /// Get the first fall frost date for a USDA zone.
    static func firstFallFrostDate(for zone: String) -> Date? {
        // Approximate: based on USDA Zone averages (median first frost)
        // Zone 3: Sep 15, Zone 4: Oct 1, Zone 5: Oct 15,
        // Zone 6: Nov 1, Zone 7: Nov 15, Zone 8: Dec 1, Zone 9: Dec 15, Zone 10: Jan 1
        let zoneNum = Int(zone) ?? 5
        let baseDate = Calendar.current.date(from: DateComponents(year: fallYear(), month: 9, day: 15))!
        let daysOffset = (zoneNum - 3) * 14  // ~2 weeks per zone
        
        return Calendar.current.date(byAdding: .day, value: daysOffset, to: baseDate)
    }
    
    /// Build a planting window for a variety, given a garden's profile.
    /// Custom frost date strings are honored; USDA-zone averages are the fallback.
    /// (Actual sow/transplant/harvest dates are computed by the `PlantingWindow` extension.)
    static func plantingWindow(
        for variety: Variety,
        usdaZone: String,
        lastFrost: String? = nil,
        firstFrost: String? = nil,
        zoneType: SurfaceZoneType = .gardenBed
    ) -> PlantingWindow {
        PlantingWindow(
            variety: variety,
            usdaZone: usdaZone,
            lastFrostDate: lastFrost,
            firstFrostDate: firstFrost,
            lightLevel: 50,
            zoneType: zoneType
        )
    }
    
    /// Parse a frost date string (e.g. "Apr 15") into a Date.
    static func parseFrostDate(_ str: String, calendar: Calendar) -> Date? {
        let parts = str.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        
        let monthStr = String(parts[0])
        let dayStr = parts[1]
        
        let months: [String: Int] = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4,
            "May": 5, "Jun": 6, "Jul": 7, "Aug": 8,
            "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
            "January": 1, "February": 2, "March": 3, "April": 4,
            "June": 6, "July": 7, "August": 8, "September": 9,
            "October": 10, "November": 11, "December": 12
        ]
        
        guard let month = months[monthStr], let day = Int(dayStr) else {
            return nil
        }
        
        // Pick the season this year if it hasn't passed yet, otherwise next season.
        let thisYear = calendar.component(.year, from: Date())
        var date = calendar.date(from: DateComponents(year: thisYear, month: month, day: day))!
        if date < Date() {
            date = calendar.date(byAdding: .year, value: 1, to: date)!
        }
        return date
    }
}

// MARK: - Calendar Computation (for PlantingCalendarView)

extension PlantingWindow {
    private var calendar: Calendar { Calendar.current }

    /// Effective last spring frost: the user's custom date (rolling forward
    /// to next season if already past), else the USDA-zone approximation.
    var lastFrost: Date? {
        FrostDateService.parseFrostDate(lastFrostDate ?? "", calendar: calendar)
            ?? FrostDateService.lastSpringFrostDate(for: usdaZone)
    }

    /// Effective first fall frost: the user's custom date, else the USDA-zone approximation.
    var firstFrost: Date? {
        FrostDateService.parseFrostDate(firstFrostDate ?? "", calendar: calendar)
            ?? FrostDateService.firstFallFrostDate(for: usdaZone)
    }

    /// Sow date: `sowOffset` days before the last frost.
    var sowDate: Date? {
        guard let lastFrost = lastFrost else { return nil }
        return calendar.date(byAdding: .day, value: -variety.sowOffset, to: lastFrost)
    }

    /// Transplant date: `transplantOffset` days before the last frost (0 = at last frost).
    var transplantDate: Date? {
        guard let lastFrost = lastFrost else { return nil }
        return calendar.date(byAdding: .day, value: -variety.transplantOffset, to: lastFrost)
    }

    /// Harvest date: days-to-maturity after sowing.
    var harvestDate: Date? {
        guard let sowDate = sowDate else { return nil }
        return calendar.date(byAdding: .day, value: variety.daysToMature, to: sowDate)
    }

    var sowDateString: String {
        sowDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }

    var transplantDateString: String {
        transplantDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }

    var harvestDateString: String {
        harvestDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }
}
