import Foundation
import Testing
@testable import WristlabCore

@Test func missingValuesSurviveRoundTrip() throws {
    let snapshot = try DashboardSnapshot(generatedAt: .distantPast, source: .healthKit, recovery: nil, energy: nil, stress: nil)
    let decoded = try JSONDecoder().decode(DashboardSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(decoded == snapshot)
    #expect(decoded.energy == nil)
}

@Test(arguments: [-1, 101]) func invalidScoresAreRejected(value: Int) {
    #expect(throws: DashboardSnapshot.ValidationError.self) {
        try DashboardSnapshot(generatedAt: .now, source: .healthKit, recovery: value, energy: nil, stress: nil)
    }
}

@Test func wirePayloadCannotBypassValidation() throws {
    let json = Data(#"{"generatedAt":0,"source":"healthKit","energy":101}"#.utf8)
    #expect(throws: DashboardSnapshot.ValidationError.self) {
        try JSONDecoder().decode(DashboardSnapshot.self, from: json)
    }
}

@Test func staleAndFutureSnapshotsAreDetected() throws {
    let snapshot = try DashboardSnapshot(generatedAt: Date(timeIntervalSince1970: 1000), source: .healthKit, recovery: 0, energy: 100, stress: nil)
    #expect(!snapshot.isStale(at: Date(timeIntervalSince1970: 4600)))
    #expect(snapshot.isStale(at: Date(timeIntervalSince1970: 4601)))
    #expect(snapshot.isStale(at: Date(timeIntervalSince1970: 999)))
}
