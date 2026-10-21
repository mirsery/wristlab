import Foundation
import WidgetKit
import WristlabCore

/// Hands the phone's latest real snapshot to its widgets. Demo reports never come through here.
enum PhoneWidgetStore {
    static func publish(_ snapshot: DisplaySnapshot) {
        guard snapshot.source == .healthKit,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PhoneWidgetCache.appGroup) else { return }
        let file = folder.appendingPathComponent(PhoneWidgetCache.fileName)
        do {
            try SnapshotCacheFile.write(snapshot.encoded(), to: file)
        } catch {
            // A failed ordinary write keeps the previous file, which still expires on its own.
            // A failed clear must not leave old values behind: remove the file so widgets wait instead.
            guard snapshot.clearData else { return }
            try? FileManager.default.removeItem(at: file)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
