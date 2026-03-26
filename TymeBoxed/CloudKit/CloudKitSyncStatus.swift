import CloudKit
import Foundation
import SwiftUI

/// iCloud account availability for Settings UI (independent of sync toggle).
@MainActor
final class CloudKitSyncStatus: ObservableObject {
  static let shared = CloudKitSyncStatus()

  @Published private(set) var isSignedIn: Bool = false

  private lazy var container: CKContainer = {
    CKContainer(identifier: CloudKitConstants.containerIdentifier)
  }()

  func refresh() async {
    do {
      let status = try await container.accountStatus()
      isSignedIn = status == .available
    } catch {
      isSignedIn = false
    }
  }
}
