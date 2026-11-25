import Foundation

public enum WatchRefreshOutcome: String, Codable, Sendable {
    case snapshotAvailable, noSnapshot, needsHealthConnection, failed
}

public struct WatchRefreshReply: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let outcome: WatchRefreshOutcome
    public let snapshot: Data?
    public init(requestID: UUID, outcome: WatchRefreshOutcome, snapshot: Data?) {
        self.requestID = requestID
        self.outcome = outcome
        self.snapshot = snapshot
    }
}

public enum WatchRefreshResponse: Equatable, Sendable {
    case reply(WatchRefreshReply), unreadable, undelivered
}

/// WatchConnectivity calls `sendMessage` handlers on its own background queue. They must stay
/// nonisolated: a MainActor closure literal passed there traps under Swift 6 (Watch 2405 crash).
public struct WatchRefreshHandlers: Sendable {
    public let reply: @Sendable ([String: Any]) -> Void
    public let failure: @Sendable (any Error) -> Void
    public init(requestID: UUID, deliver: @escaping @MainActor @Sendable (WatchRefreshResponse) -> Void) {
        reply = { message in
            let response: WatchRefreshResponse
            if let data = message["refreshReply"] as? Data,
               let value = try? JSONDecoder().decode(WatchRefreshReply.self, from: data), value.requestID == requestID {
                response = .reply(value)
            } else { response = .unreadable }
            Task { @MainActor in deliver(response) }
        }
        failure = { _ in Task { @MainActor in deliver(.undelivered) } }
    }
}

public struct WatchRefreshState: Sendable {
    public enum Phase: Sendable {
        case idle, waiting, unreachable, activationFailed, timedOut, failed, noSnapshot, needsHealthConnection
    }
    public private(set) var requestID: UUID?
    public private(set) var phase: Phase = .idle
    public init() {}
    public mutating func begin(_ requestID: UUID, reachable: Bool, activated: Bool) -> Bool {
        guard self.requestID == nil else { return false }
        guard activated else { phase = .activationFailed; return false }
        guard reachable else { phase = .unreachable; return false }
        self.requestID = requestID
        phase = .waiting
        return true
    }
    public mutating func complete(_ requestID: UUID, phase: Phase) {
        guard self.requestID == requestID else { return }
        self.requestID = nil
        self.phase = phase
    }
}

public enum WatchRefreshResponder {
    @MainActor public static func respond(
        requestID: UUID,
        cached: () async -> Data?,
        refresh: () async -> WatchRefreshOutcome,
        reply: (WatchRefreshReply) -> Void
    ) async {
        if let snapshot = await cached() {
            reply(WatchRefreshReply(requestID: requestID, outcome: .snapshotAvailable, snapshot: snapshot))
            _ = await refresh()
        } else {
            let result = await refresh()
            let snapshot = await cached()
            reply(WatchRefreshReply(requestID: requestID, outcome: snapshot == nil ? result : .snapshotAvailable, snapshot: snapshot))
        }
    }
}

public enum WatchSnapshotDelivery {
    public static func accept(
        _ snapshot: DisplaySnapshot,
        receiver: inout SnapshotReceiver,
        confirmProducer: Bool,
        persist: (Data) throws -> Void
    ) throws {
        var next = receiver
        try next.accept(snapshot, confirmProducer: confirmProducer)
        try persist(JSONEncoder().encode(next))
        receiver = next
    }
}
