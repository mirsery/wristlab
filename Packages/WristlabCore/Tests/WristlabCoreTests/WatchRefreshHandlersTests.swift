import Foundation
import Testing
@testable import WristlabCore

/// WatchConnectivity invokes `sendMessage` handlers on its own background queue.
struct WatchRefreshHandlersTests {
    /// The first delivered response, or nil when nothing arrives within five seconds.
    private func delivered(_ requestID: UUID, invoke: @escaping @Sendable (WatchRefreshHandlers) -> Void) async -> WatchRefreshResponse? {
        var continuation: AsyncStream<WatchRefreshResponse>.Continuation!
        let stream = AsyncStream<WatchRefreshResponse> { continuation = $0 }
        let handlers = WatchRefreshHandlers(requestID: requestID) { [continuation] in continuation!.yield($0) }
        DispatchQueue.global(qos: .utility).async { invoke(handlers) }
        return await withTaskGroup(of: WatchRefreshResponse?.self) { group in
            group.addTask { await stream.first { _ in true } }
            group.addTask { try? await Task.sleep(for: .seconds(5)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // TC-WRX-001
    @Test func replyFromBackgroundQueueReachesMainActor_TC_WRX_001() async throws {
        let request = UUID()
        let sent = WatchRefreshReply(requestID: request, outcome: .snapshotAvailable, snapshot: Data([1, 2, 3]))
        let payload = try JSONEncoder().encode(sent)
        let response = await delivered(request) { $0.reply(["refreshReply": payload]) }
        #expect(response == .reply(sent))
    }

    // TC-WRX-002
    @Test func invalidRepliesAndErrorsReachMainActor_TC_WRX_002() async throws {
        let request = UUID()
        let foreign = try JSONEncoder().encode(WatchRefreshReply(requestID: UUID(), outcome: .noSnapshot, snapshot: nil))
        let messages: [[String: Data]] = [["refreshReply": foreign], [:], ["refreshReply": Data("not json".utf8)]]
        for message in messages {
            let response = await delivered(request) { $0.reply(message) }
            #expect(response == .unreadable)
        }
        let failure = await delivered(request) { $0.failure(CocoaError(.featureUnsupported)) }
        #expect(failure == .undelivered)
    }
}
