import SwiftUI
import WristlabCore

@main
struct WristlabWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ScrollView { DashboardView(snapshot: .demo) }
        }
    }
}
