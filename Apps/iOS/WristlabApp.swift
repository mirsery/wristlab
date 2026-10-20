import SwiftUI

@main
struct WristlabApp: App {
    @UIApplicationDelegateAdaptor(WristlabAppDelegate.self) private var appDelegate
    @StateObject private var model = AppServices.dashboard
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
