import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

@MainActor
class RequestAuthorizer: ObservableObject {
  @Published var isAuthorized = false

  func requestAuthorization(completion: (() -> Void)? = nil) {
    // If already authorized (e.g. re-login after account delete - permissions persist on device),
    // set state immediately and dismiss so user goes to Home
    if AuthorizationCenter.shared.authorizationStatus == .approved {
      isAuthorized = true
      completion?()
      return
    }

    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        print("Individual authorization successful")
        self.isAuthorized = true
        completion?()
      } catch {
        print("Error requesting authorization: \(error)")
        self.isAuthorized = false
      }
    }
  }

  func getAuthorizationStatus() -> AuthorizationStatus {
    return AuthorizationCenter.shared.authorizationStatus
  }
}
