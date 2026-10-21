import Foundation

public enum ComplicationMetric: String, CaseIterable, Codable, Sendable, Identifiable {
    case energy, readiness, stress
    public var id: String { rawValue }
    public var title: String {
        switch self { case .energy: "身体电量"; case .readiness: "训练准备度"; case .stress: "生理压力" }
    }
    public var shortTitle: String {
        switch self { case .energy: "电量"; case .readiness: "准备度"; case .stress: "压力" }
    }
    public var symbol: String {
        switch self { case .energy: "battery.75percent"; case .readiness: "leaf"; case .stress: "waveform.path.ecg" }
    }
    public var widgetKind: String {
        switch self { case .energy: "WristlabEnergy"; case .readiness: "WristlabReadiness"; case .stress: "WristlabStress" }
    }
    public func estimate(in snapshot: DisplaySnapshot) -> MetricEstimate {
        switch self { case .energy: snapshot.energy; case .readiness: snapshot.readiness; case .stress: snapshot.stress }
    }
}

public enum ComplicationState: String, Sendable {
    case current, partial, awaitingSync, cleared, calibrating, insufficientData, unsupported, failed, stale
}

/// A read-only display decision shared by every complication family.
public struct ComplicationPresentation: Equatable, Sendable {
    public let metric: ComplicationMetric
    public let value: Int?
    public let state: ComplicationState
    public let updatedAt: Date?
    public let baselineDays: Int
    private let explanation: MetricExplanation?
    public var detailText: String {
        switch state {
        case .awaitingSync: "尚未收到可用手机快照。请在手机打开Wristlab，连接健康数据并刷新，再保持两端连接。"
        case .cleared: "手机已清除应用数据。请在手机重新读取后同步；清除不会删除Apple健康原始记录。"
        case .stale: "快照或指标已超过有效时间。请在手机刷新并保持两端连接；旧记录不会因刷新变成新记录。"
        default: explanation?.detail ?? "等待更多有效记录。"
        }
    }
    public var statusText: String {
        switch state {
        case .current: "基于个人历史"
        case .partial: "部分估算"
        case .awaitingSync: "等待手机"
        case .cleared: "数据已清除"
        case .calibrating: explanation?.summary ?? "校准中 · \(baselineDays)/14天"
        case .insufficientData: explanation?.summary ?? "数据不足"
        case .unsupported: "暂不支持"
        case .failed: "读取失败"
        case .stale: "已过期"
        }
    }
    public init(snapshot: DisplaySnapshot?, metric: ComplicationMetric, at now: Date) {
        self.metric = metric
        guard let snapshot, (try? snapshot.validate()) != nil, snapshot.source == .healthKit else {
            value = nil; state = .awaitingSync; updatedAt = nil; baselineDays = 0; explanation = nil
            return
        }
        updatedAt = snapshot.computedAt
        let estimate = metric.estimate(in: snapshot)
        baselineDays = estimate.baselineDays
        explanation = MetricExplanation(estimate, at: now)
        if snapshot.clearData {
            value = nil; state = .cleared
        } else if snapshot.isStale(at: now) || estimate.isStale(at: now) {
            value = nil; state = .stale
        } else if let score = estimate.value {
            value = score; state = estimate.quality == .partial ? .partial : .current
        } else {
            value = nil
            switch estimate.availability {
            case .calibrating: state = .calibrating
            case .unsupported: state = .unsupported
            case .failed: state = .failed
            case .available, .insufficientData: state = .insufficientData
            }
        }
    }
}

public enum ComplicationCache {
    /// Retain valid tombstones so views can explain that data was cleared.
    public static func snapshot(from data: Data?) -> DisplaySnapshot? {
        guard let data, data.count <= 65536,
              let receiver = try? JSONDecoder().decode(SnapshotReceiver.self, from: data),
              let snapshot = receiver.snapshot, (try? snapshot.validate()) != nil,
              snapshot.source == .healthKit else { return nil }
        return snapshot
    }
}

public enum ComplicationTimeline {
    public static func dates(snapshot: DisplaySnapshot?, now: Date) -> [Date] {
        guard let snapshot, (try? snapshot.validate()) != nil, snapshot.source == .healthKit,
              !snapshot.clearData, !snapshot.isStale(at: now) else { return [now] }
        let expiry = [snapshot.computedAt.addingTimeInterval(3600)] +
            ComplicationMetric.allCases.compactMap { $0.estimate(in: snapshot).validUntil }
        let transitions = expiry.map { $0.addingTimeInterval(1) }.filter { $0 > now }
        return Array(Set([now] + transitions)).sorted()
    }
}

public enum ComplicationDestination: String, CaseIterable, Hashable, Sendable, Identifiable {
    case overview, energy, readiness, stress
    public var id: String { rawValue }
    public var metric: ComplicationMetric? { ComplicationMetric(rawValue: rawValue) }
    public var url: URL {
        // The scheme, host, and four raw values are fixed valid URL literals.
        URL(string: "wristlab://complication/\(rawValue)")!
    }
    public init(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "wristlab", parts.host?.lowercased() == "complication",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil,
              let route = Self.allCases.first(where: { parts.percentEncodedPath == "/\($0.rawValue)" }) else {
            self = .overview; return
        }
        self = route
    }
}

// MARK: - iPhone widgets

/// The phone writes its own latest snapshot; the widget accepts only a valid real one or a clear marker.
public enum PhoneWidgetCache {
    public static let appGroup = "group.com.mirsery.wristlab.phone"
    public static let fileName = "phone-snapshot.json"
    /// Same bound as DisplaySnapshot.validate (32 KB).
    public static let maximumBytes = 32768
    public static func snapshot(from data: Data?) -> DisplaySnapshot? {
        guard let data, data.count <= maximumBytes, let snapshot = try? DisplaySnapshot.decode(data), snapshot.source == .healthKit else { return nil }
        return snapshot
    }
}

/// Readiness, energy and stress for the phone widget, under the same rules as the Watch complications.
public struct PhoneWidgetSummary: Equatable, Sendable {
    public let metrics: [ComplicationPresentation]
    public let updatedAt: Date?
    private let snapshot: DisplaySnapshot?

    public init(snapshot: DisplaySnapshot?, at now: Date) {
        self.snapshot = snapshot
        metrics = [ComplicationMetric.readiness, .energy, .stress].map { ComplicationPresentation(snapshot: snapshot, metric: $0, at: now) }
        updatedAt = metrics.compactMap(\.updatedAt).first
    }
    public func dates(now: Date) -> [Date] { ComplicationTimeline.dates(snapshot: snapshot, now: now) }
    /// The phone is the producer, so "waiting for the phone" becomes a prompt to refresh.
    public func statusText(_ metric: ComplicationPresentation) -> String {
        metric.state == .awaitingSync ? "打开Wristlab刷新" : metric.statusText
    }
}
