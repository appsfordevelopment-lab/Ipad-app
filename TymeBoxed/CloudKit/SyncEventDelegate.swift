import Foundation

/// Typed contract for sync events from ProfileSyncManager to SyncCoordinator.
@MainActor
protocol SyncEventDelegate: AnyObject {
  func didReceiveSyncedProfiles(_ profiles: [SyncedProfile], remoteProfileIds: Set<UUID>)
  func didReceiveSessionRecords(_ sessions: [ProfileSessionRecord])
  func didReceiveEmergencyState(_ state: SyncedEmergencyState)
  func didReceiveSyncReset(clearAppSelections: Bool)
  func didRequestLocalDataPush()
}
