import CloudKit
import UIKit

/// Registers for push and forwards CloudKit notifications to `ProfileSyncManager`.
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    application.registerForRemoteNotifications()
    return true
  }

  func application(
    _: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken _: Data
  ) {
    Log.info("Registered for remote notifications", category: .app)
  }

  func application(
    _: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    Log.error("Failed to register for remote notifications: \(error)", category: .app)
  }

  func application(
    _: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
      Task { @MainActor in
        await ProfileSyncManager.shared.handleRemoteNotification()
        completionHandler(.newData)
      }
    } else {
      completionHandler(.noData)
    }
  }
}
