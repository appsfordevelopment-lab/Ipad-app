import Foundation
import SwiftUI

/// Manages sync conflicts between schema versions (e.g. mixed app versions).
@MainActor
final class SyncConflictManager: ObservableObject {
  static let shared = SyncConflictManager()

  @Published var conflictedProfiles: [UUID: String] = [:]
  @Published var newerVersionProfiles: [UUID: String] = [:]
  @Published var showConflictBanner: Bool = false

  func addConflict(profileId: UUID, profileName: String) {
    conflictedProfiles[profileId] = profileName
    showConflictBanner = true
  }

  func addNewerVersionConflict(profileId: UUID, profileName: String) {
    newerVersionProfiles[profileId] = profileName
    showConflictBanner = true
  }

  func dismissBanner() {
    showConflictBanner = false
  }

  func clearConflict(profileId: UUID) {
    conflictedProfiles.removeValue(forKey: profileId)
    newerVersionProfiles.removeValue(forKey: profileId)
    if conflictedProfiles.isEmpty && newerVersionProfiles.isEmpty {
      showConflictBanner = false
    }
  }

  func clearAll() {
    conflictedProfiles.removeAll()
    newerVersionProfiles.removeAll()
    showConflictBanner = false
  }

  var shouldShowNewerVersionBanner: Bool {
    !newerVersionProfiles.isEmpty && showConflictBanner
  }

  var shouldShowOlderDeviceBanner: Bool {
    !conflictedProfiles.isEmpty && showConflictBanner
  }

  var conflictMessage: String {
    if conflictedProfiles.count == 1, let name = conflictedProfiles.values.first {
      return
        "\"\(name)\" was edited on an older app version. Update Tyme Boxed on all devices to sync."
    }
    return "Several profiles were edited on an older app version. Update Tyme Boxed on all devices to sync."
  }

  var newerVersionMessage: String {
    if newerVersionProfiles.count == 1, let name = newerVersionProfiles.values.first {
      return
        "\"\(name)\" was updated on a newer version of Tyme Boxed. Update this device to continue syncing."
    }
    return "Some profiles were updated on a newer version of Tyme Boxed. Update this device to continue syncing."
  }
}
