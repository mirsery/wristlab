import UIKit

@MainActor
enum AppServices {
    static let dashboard = DashboardModel()
}

@MainActor
final class WristlabAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // HealthKit may launch the process without creating a foreground scene.
        // Register observers at application launch, rather than relying on a view task.
        Task { await AppServices.dashboard.restoreObservers() }
        return true
    }
}
