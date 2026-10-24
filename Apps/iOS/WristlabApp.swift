import SwiftUI
import CloudKit

@main
struct WristlabApp: App {
    @UIApplicationDelegateAdaptor(WristlabAppDelegate.self) private var appDelegate
    @StateObject private var model = AppServices.dashboard
    @StateObject private var cloud = AppServices.cloudPreferences
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            PhoneDashboardView(model: model)
                .preferredColorScheme(.dark)
                .task {
                    cloud.setDemo(ProcessInfo.processInfo.arguments.contains("--demo"))
                    await model.start()
                    if !model.demoEnabled { await cloud.checkAccount() }
                }
                .onChange(of: model.demoEnabled) { _, enabled in cloud.setDemo(enabled) }
                .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in cloud.accountChanged() }
                .onChange(of: phase) { _, value in
                    if value == .active { Task { await cloud.checkAccount(); await model.refresh() } }
                }
        }
    }
}
