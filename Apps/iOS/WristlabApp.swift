import SwiftUI

@main
struct WristlabApp: App {
    @StateObject private var model = DashboardModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            PhoneDashboardView(model: model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
                .onChange(of: phase) { _, value in
                    if value == .active { Task { await model.refresh() } }
                }
        }
    }
}
