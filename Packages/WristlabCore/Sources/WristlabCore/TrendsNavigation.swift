public enum TrendsSection: String, CaseIterable, Sendable {
    case health, movement, weight
    public var title: String {
        switch self { case .health: "健康"; case .movement: "运动"; case .weight: "体重" }
    }
    public var metrics: [TrendMetric] {
        switch self {
        case .health: [.readiness, .sleep, .nightHRV, .restingHeartRate]
        case .movement: [.load]
        case .weight: []
        }
    }
    public var requiresHealthReport: Bool { self == .health }
    public var periodExplanation: String {
        switch self {
        case .health: "图表可选7/30日；健康回顾固定近7日对比此前28日，节奏为报告日，心情为最近7日。"
        case .movement: "计划回顾按本分析周；负荷图可选7/30日，两者周期独立。"
        case .weight: "体重周均按分析周，至少3个记录日才显示；不是7/30日筛选结果。"
        }
    }
}

public struct TrendsNavigationState: Sendable {
    public var selected: TrendsSection = .health
    private var healthMetric: TrendMetric = .readiness
    private var healthLength = 7
    private var movementLength = 7
    private var positions: [TrendsSection: String] = [:]
    public init() {}
    public func metric(for section: TrendsSection) -> TrendMetric? {
        switch section { case .health: healthMetric; case .movement: .load; case .weight: nil }
    }
    public func length(for section: TrendsSection) -> Int? {
        switch section { case .health: healthLength; case .movement: movementLength; case .weight: nil }
    }
    public mutating func selectHealthMetric(_ metric: TrendMetric) {
        guard TrendsSection.health.metrics.contains(metric) else { return }
        healthMetric = metric
    }
    public mutating func setLength(_ length: Int, for section: TrendsSection) {
        guard length == 7 || length == 30 else { return }
        switch section { case .health: healthLength = length; case .movement: movementLength = length; case .weight: break }
    }
    public func position(for section: TrendsSection) -> String? { positions[section] }
    public mutating func rememberPosition(_ position: String?, for section: TrendsSection) { positions[section] = position }
    public mutating func resetContentPositions() { positions = [:] }
    public var interfacePreferences: InterfacePreferences {
        var value = InterfacePreferences()
        value.section = selected.rawValue; value.metric = healthMetric.rawValue
        value.healthDays = healthLength; value.movementDays = movementLength
        return value
    }
    public mutating func apply(_ preferences: InterfacePreferences) {
        guard (try? preferences.validate()) != nil else { return }
        selected = TrendsSection(rawValue: preferences.section) ?? .health
        healthMetric = TrendMetric(rawValue: preferences.metric) ?? .readiness
        healthLength = preferences.healthDays; movementLength = preferences.movementDays
    }
}
