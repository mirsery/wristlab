import SwiftUI
import WristlabCore

@main
struct WristlabApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    DashboardView(snapshot: .demo)
                    HealthAccessView()
                }
                .navigationTitle("今日")
            }
            .preferredColorScheme(.dark)
        }
    }
}
