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
    
    /// Calculate planting windows for a variety, given a garden's profile.
    static func plantingWindow(
        for variety: Variety,
        usdaZone: String,
        lastFrost: String? = nil,
        firstFrost: String? = nil
    ) -> [PlantingWindow] {
        var windows: [PlantingWindow] = []
        
        // Get the frost dates (from profile or USDA approximation)
        let calendar = Calendar.current
        
        // Try to parse custom frost dates first
        let lastFrostParsed = parseFrostDate(lastFrost ?? "", calendar: calendar)
        let firstFrostParsed = parseFrostDate(firstFrost ?? "", calendar: calendar)
        
        // Fallback to USDA zone approximation
        let effectiveLastFrost = lastFrostParsed ?? lastSpringFrostDate(for: usdaZone) ?? calendar.date(from: DateComponents(year: springYear(), month: 4, day: 15))!
        let effectiveFirstFrost = firstFrostParsed ?? firstFallFrostDate(for: usdaZone) ?? calendar.date(from: DateComponents(year: fallYear(), month: 10, day: 15))!
        
        // Direct seeding window (plant directly in ground)
        let sowDate = calendar.date(byAdding: .day, value: -variety.sowOffset, to: effectiveLastFrost)!
        let harvestDate = calendar.date(byAdding: .day, value: variety.daysToMature, to: sowDate)!
        
        windows.append(PlantingWindow(
            variety: variety,
            usdaZone: usdaZone,
            lastFrostDate: lastFrost,
            firstFrostDate: firstFrost,
            lightLevel: 50,
            zoneType: .gardenBed
        ))
        
        // Succession planting (if harvest window allows multiple cycles)
        let growingDays = Int(effectiveFirstFrost.timeIntervalSince(effectiveLastFrost))
        let cycles = variety.daysToMature > 0 ? growingDays / variety.daysToMature : 1
        
        for cycle in 1..<cycles {
            let cycleStart = calendar.date(byAdding: .day, value: cycle * (variety.daysToMature - variety.harvestWindow), to: effectiveLastFrost)!
            let cycleSow = calendar.date(byAdding: .day, value: -variety.sowOffset, to: cycleStart)!
            
            windows.append(PlantingWindow(
                variety: variety,
                usdaZone: usdaZone,
                lastFrostDate: lastFrost,
                firstFrostDate: firstFrost,
                lightLevel: 50,
                zoneType: .gardenBed
            ))
        }
        
        return windows
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
    var sowDateString: String {
        guard let lastFrost = FrostDateService.lastSpringFrostDate(for: usdaZone) else { return "—" }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -variety.sowOffset, to: lastFrost)
            .map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }
    
    var transplantDateString: String {
        guard let lastFrost = FrostDateService.lastSpringFrostDate(for: usdaZone) else { return "—" }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -variety.transplantOffset, to: lastFrost)
            .map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }
    
    var harvestDateString: String {
        guard let lastFrost = FrostDateService.lastSpringFrostDate(for: usdaZone) else { return "—" }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: variety.daysToMature, to: lastFrost)
            .map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }
}
