import UIKit
import UserNotifications

@MainActor
enum AppServices {
    static let dashboard = DashboardModel()
}

@MainActor
final class WristlabAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The morning brief is often produced by the refresh that runs when the app opens; show it then too.
        UNUserNotificationCenter.current().delegate = self
        // HealthKit may launch the process without creating a foreground scene.
        // Register observers at application launch, rather than relying on a view task.
        Task { await AppServices.dashboard.restoreObservers() }
        return true
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
