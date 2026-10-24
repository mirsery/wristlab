import Foundation
import HealthKit
import WristlabCore

@MainActor private func verifySummaryDate(_ timestamp: String, zone: String) throws {
    guard let date = ISO8601DateFormatter().date(from: timestamp) else {
        fatalError("Invalid synthetic activity date")
    }
    let clock = try AnalysisClock(timeZoneID: zone)
    let components = DailyActivityReader.summaryDateComponents(at: date, clock: clock)
    withExtendedLifetime(HKQuery.predicateForActivitySummary(with: components)) {}
    let expected = clock.calendar.dateComponents([.era, .year, .month, .day], from: date)
    precondition(components.calendar?.identifier == .gregorian)
    precondition(components.calendar?.timeZone == clock.calendar.timeZone)
    precondition(components.timeZone == clock.calendar.timeZone)
    precondition(components.era == expected.era && components.year == expected.year)
    precondition(components.month == expected.month && components.day == expected.day)
}

@MainActor func checkActivityCalendar_TC_ACAL_001() throws {
    for zone in ["UTC", "Asia/Shanghai", "America/New_York"] {
        try verifySummaryDate("2026-10-24T00:15:00Z", zone: zone)
    }
    print("ACTIVITY_DATE: TC-ACAL-001 OK")
}

@MainActor func checkActivityDayBoundaries_TC_ACAL_002() throws {
    for timestamp in ["2026-03-08T06:59:00Z", "2026-03-08T07:01:00Z", "2026-11-01T05:59:00Z", "2026-11-01T06:01:00Z"] {
        try verifySummaryDate(timestamp, zone: "America/New_York")
    }
    try verifySummaryDate("2026-10-23T16:01:00Z", zone: "Asia/Shanghai")
    try verifySummaryDate("2026-10-24T03:59:00Z", zone: "America/New_York")
    print("ACTIVITY_DATE: TC-ACAL-002 OK")
}

@MainActor func checkRepeatedActivityPredicate_TC_ACAL_003() throws {
    for _ in 0..<20 { try verifySummaryDate("2026-10-24T00:15:00Z", zone: "Asia/Shanghai") }
    print("ACTIVITY_DATE: TC-ACAL-003 CONTRACT OK")
}
