import Foundation

public enum DataSource: String, Codable, Sendable {
    case demo
    case healthKit
}

public struct DashboardSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let source: DataSource
    public let recovery: Int?
    public let energy: Int?
    public let stress: Int?

    public init(generatedAt: Date, source: DataSource, recovery: Int?, energy: Int?, stress: Int?) throws {
        for value in [recovery, energy, stress].compactMap({ $0 }) {
            guard (0...100).contains(value) else { throw ValidationError.outOfRange }
        }
        self.generatedAt = generatedAt
        self.source = source
        self.recovery = recovery
        self.energy = energy
        self.stress = stress
    }

    public enum ValidationError: Error { case outOfRange }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            generatedAt: values.decode(Date.self, forKey: .generatedAt),
            source: values.decode(DataSource.self, forKey: .source),
            recovery: values.decodeIfPresent(Int.self, forKey: .recovery),
            energy: values.decodeIfPresent(Int.self, forKey: .energy),
            stress: values.decodeIfPresent(Int.self, forKey: .stress)
        )
    }

    public func isStale(at now: Date, maximumAge: TimeInterval = 3600) -> Bool {
        now.timeIntervalSince(generatedAt) > maximumAge || generatedAt > now
    }

    public static var demo: Self {
        // Fixed synthetic timestamp makes fixtures deterministic and visibly stale.
        try! Self(generatedAt: Date(timeIntervalSince1970: 1_792_483_200), source: .demo, recovery: 82, energy: 68, stress: 24)
    }
}
