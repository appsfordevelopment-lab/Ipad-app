import Foundation
import SwiftData
import UIKit

/// Coordinates ProfileSyncManager events with local SwiftData storage.
@MainActor
class SyncCoordinator: ObservableObject {
  static let shared = SyncCoordinator(
    sessionController: StrategyManager.shared,
    syncManager: ProfileSyncManager.shared)

  private let sessionController: SessionController
  private let syncManager: ProfileSyncManager
  private var modelContext: ModelContext?
  private var pushTask: Task<Void, Never>?

  private var remoteTriggeredProfileIds: Set<UUID> = []

  init(sessionController: SessionController, syncManager: ProfileSyncManager) {
    self.sessionController = sessionController
    self.syncManager = syncManager
    if let existing = syncManager.syncEventDelegate, existing !== self {
      Log.warning(
        "Overwriting existing syncEventDelegate — multiple SyncCoordinator instances detected",
        category: .sync)
    }
    syncManager.syncEventDelegate = self
  }

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  // MARK: - Local push

  private func pushLocalData() {
    guard syncManager.isEnabled else {
      Log.info("Global sync disabled, skipping push", category: .sync)
      return
    }

    guard modelContext != nil else {
      Log.info("No model context available for local push", category: .sync)
      return
    }

    let previousTask = pushTask
    pushTask = Task { @MainActor in
      await previousTask?.value
      guard syncManager.isEnabled, let context = modelContext else {
        return
      }
      do {
        // Fetch after prior tasks finish so we never push profiles removed by a concurrent
        // pull (e.g. phone deleted from iCloud while an older push queue was still in flight).
        let profiles = try BlockedProfiles.fetchProfiles(in: context)

        Log.info("Found \(profiles.count) profiles to sync", category: .sync)

        let deviceId = SharedData.deviceSyncId.uuidString
        let syncedProfiles = profiles.filter { !$0.isNewerSchemaVersion }
          .map { SyncedProfile.forCloudPush(from: $0, originDeviceId: deviceId) }

        Log.info("Pushing \(syncedProfiles.count) profiles to CloudKit", category: .sync)

        for syncedProfile in syncedProfiles {
          do {
            try await syncManager.pushSyncedProfile(syncedProfile)
          } catch {
            Log.error(
              "Failed to push profile '\(syncedProfile.name)': \(error.localizedDescription)",
              category: .sync)
          }
        }
        do {
          try await syncManager.pushEmergencyState()
        } catch {
          Log.error(
            "Failed to push emergency state: \(error.localizedDescription)",
            category: .sync)
        }
      } catch {
        Log.info("Error pushing local data - \(error)", category: .sync)
      }
    }
  }

  // MARK: - Profiles

  private func handleSyncedProfiles(
    _ syncedProfiles: [SyncedProfile],
    remoteProfileIds: Set<UUID>
  ) {
    guard let context = modelContext else {
      Log.info("No model context available", category: .sync)
      return
    }

    let deviceId = SharedData.deviceSyncId.uuidString
    let locallyRemovedIds = SharedData.locallyRemovedProfileIdsForSync

    for syncedProfile in syncedProfiles {
      // Match iPhone: skip our own pushes only when we still have the row locally, so restores /
      // same deviceSyncId edge cases still apply incoming records.
      if syncedProfile.originDeviceId == deviceId {
        let existsLocally =
          (try? BlockedProfiles.findProfile(byID: syncedProfile.profileId, in: context)) != nil
        if existsLocally {
          continue
        }
      }

      if locallyRemovedIds.contains(syncedProfile.profileId) {
        continue
      }

      do {
        if let existingProfile = try BlockedProfiles.findProfile(
          byID: syncedProfile.profileId,
          in: context
        ) {
          if syncedProfile.profileSchemaVersion < existingProfile.profileSchemaVersion {
            Log.warning(
              "Ignoring sync from older schema version for profile: \(existingProfile.name)",
              category: .sync)
            SyncConflictManager.shared.addConflict(
              profileId: existingProfile.id,
              profileName: existingProfile.name
            )
            pushProfile(existingProfile)
            Log.info(
              "Auto-healed: pushed newer schema back to CloudKit for '\(existingProfile.name)'",
              category: .sync)
          } else if syncedProfile.profileSchemaVersion
            > TymeBoxedSyncSchema.currentProfileSchemaVersion
          {
            Log.warning(
              "Ignoring sync from newer schema version for profile: \(existingProfile.name)",
              category: .sync)
            SyncConflictManager.shared.addNewerVersionConflict(
              profileId: existingProfile.id,
              profileName: existingProfile.name
            )
            existingProfile.profileSchemaVersion = syncedProfile.profileSchemaVersion
            existingProfile.syncVersion = max(1, syncedProfile.version)
          } else if syncedProfile.version > existingProfile.syncVersion {
            updateLocalProfile(existingProfile, from: syncedProfile, in: context)
            SyncConflictManager.shared.clearConflict(profileId: existingProfile.id)
          }
        } else {
          createLocalProfile(from: syncedProfile, in: context)
        }
      } catch {
        Log.info("Error handling synced profile - \(error)", category: .sync)
      }
    }

    // Heal legacy/local rows that still mirror a remote profile but never got a positive syncVersion,
    // so deletion reconciliation (`syncVersion > 0`) can remove them after phone deletes from iCloud.
    for synced in syncedProfiles {
      guard let local = try? BlockedProfiles.findProfile(byID: synced.profileId, in: context),
        local.syncVersion == 0
      else { continue }
      local.syncVersion = max(1, synced.version)
    }

    if remoteProfileIds.isEmpty && !syncedProfiles.isEmpty {
      Log.warning(
        "Remote profile IDs set is empty but decoded profiles exist — skipping deletion reconciliation",
        category: .sync)
    } else {
      do {
        let localProfiles = try BlockedProfiles.fetchProfiles(in: context)
        for profile in localProfiles {
          guard profile.syncVersion > 0 else { continue }

          if !remoteProfileIds.contains(profile.id) {
            Log.info(
              "Removing profile '\(profile.name)' deleted from remote", category: .sync)
            try BlockedProfiles.deleteProfile(profile, in: context)
          }
        }
      } catch {
        Log.info("Error reconciling profile deletions - \(error)", category: .sync)
      }
    }

    applyIPadNFCPauseFocusAdaptationsIfNeeded(in: context)

    do {
      try context.save()
    } catch {
      Log.error(
        "Failed to save synced profiles: \(error.localizedDescription)", category: .sync)
    }
  }

  /// iPads without NFC cannot run "Focus session with Break" (`NFCPauseTimerBlockingStrategy`).
  /// Run it as Manual + breaks (pause length → break length) locally while preserving CloudKit data.
  func applyIPadNFCPauseFocusAdaptationsIfNeeded(in context: ModelContext) {
    guard IPadNFCPauseAdaptation.shouldAdaptNFCPauseForCurrentDevice else { return }

    do {
      let profiles = try BlockedProfiles.fetchProfiles(in: context)
      for profile in profiles {
        adaptNFCPauseProfileForIPadWithoutNFC(profile, in: context)
      }
    } catch {
      Log.info("iPad NFCPause adaptation: \(error)", category: .sync)
    }
  }

  private func adaptNFCPauseProfileForIPadWithoutNFC(
    _ profile: BlockedProfiles,
    in context: ModelContext
  ) {
    if profile.blockingStrategyId != NFCPauseTimerBlockingStrategy.id {
      if IPadNFCPauseAdaptation.canonical(for: profile.id) != nil,
        profile.blockingStrategyId != ManualBlockingStrategy.id
      {
        IPadNFCPauseAdaptation.clear(for: profile.id)
      }
      return
    }

    let pauseData = StrategyPauseTimerData.toStrategyPauseTimerData(
      from: profile.strategyData ?? Data())
    let canonical = IPadNFCPauseAdaptation.Canonical(
      blockingStrategyId: NFCPauseTimerBlockingStrategy.id,
      strategyData: profile.strategyData,
      enableBreaks: profile.enableBreaks,
      breakTimeInMinutes: profile.breakTimeInMinutes
    )
    IPadNFCPauseAdaptation.store(canonical: canonical, for: profile.id)

    profile.blockingStrategyId = ManualBlockingStrategy.id
    profile.enableBreaks = true
    profile.breakTimeInMinutes = max(1, pauseData.pauseDurationInMinutes)
    profile.strategyData = nil
    profile.updatedAt = Date()
    BlockedProfiles.updateSnapshot(for: profile)

    Log.info(
      "Adapted '\(profile.name)' for iPad: NFCPauseTimer → Manual with \(profile.breakTimeInMinutes) min breaks",
      category: .sync)
  }

  private func updateLocalProfile(
    _ profile: BlockedProfiles,
    from synced: SyncedProfile,
    in context: ModelContext
  ) {
    profile.name = synced.name
    profile.blockingStrategyId = synced.blockingStrategyId
    profile.strategyData = synced.strategyData
    profile.order = synced.order
    profile.enableLiveActivity = synced.enableLiveActivity
    profile.reminderTimeInSeconds = synced.reminderTimeInSeconds
    profile.customReminderMessage = synced.customReminderMessage
    profile.enableBreaks = synced.enableBreaks
    profile.breakTimeInMinutes = synced.breakTimeInMinutes
    profile.enableStrictMode = synced.enableStrictMode
    profile.enableAllowMode = synced.enableAllowMode
    profile.enableAllowModeDomains = synced.enableAllowModeDomains
    profile.enableSafariBlocking = synced.enableSafariBlocking
    profile.physicalUnblockNFCTagId = synced.physicalUnblockNFCTagId
    profile.physicalUnblockQRCodeId = synced.physicalUnblockQRCodeId
    profile.domains = synced.domains
    profile.schedule = synced.schedule
    profile.disableBackgroundStops = synced.disableBackgroundStops
    profile.syncVersion = max(1, synced.version)
    profile.updatedAt = synced.updatedAt
    profile.profileSchemaVersion = max(profile.profileSchemaVersion, synced.profileSchemaVersion)
    profile.scheduleLastStoppedAt = synced.scheduleLastStoppedAt

    BlockedProfiles.updateSnapshot(for: profile)

    Log.info("Updated profile '\(profile.name)' from remote", category: .sync)
  }

  private func createLocalProfile(from synced: SyncedProfile, in context: ModelContext) {
    let profile = BlockedProfiles(
      id: synced.profileId,
      name: synced.name,
      createdAt: synced.createdAt,
      updatedAt: synced.updatedAt,
      blockingStrategyId: synced.blockingStrategyId ?? NFCBlockingStrategy.id,
      strategyData: synced.strategyData,
      enableLiveActivity: synced.enableLiveActivity,
      reminderTimeInSeconds: synced.reminderTimeInSeconds,
      customReminderMessage: synced.customReminderMessage,
      enableBreaks: synced.enableBreaks,
      breakTimeInMinutes: synced.breakTimeInMinutes,
      enableStrictMode: synced.enableStrictMode,
      enableAllowMode: synced.enableAllowMode,
      enableAllowModeDomains: synced.enableAllowModeDomains,
      enableSafariBlocking: synced.enableSafariBlocking,
      order: synced.order,
      domains: synced.domains,
      physicalUnblockNFCTagId: synced.physicalUnblockNFCTagId,
      physicalUnblockQRCodeId: synced.physicalUnblockQRCodeId,
      schedule: synced.schedule,
      disableBackgroundStops: synced.disableBackgroundStops,
      syncVersion: max(1, synced.version),
      needsAppSelection: true,
      profileSchemaVersion: synced.profileSchemaVersion,
      scheduleLastStoppedAt: synced.scheduleLastStoppedAt
    )

    context.insert(profile)
    BlockedProfiles.updateSnapshot(for: profile)

    Log.info("Created profile '\(profile.name)' from remote (needs app selection)", category: .sync)
  }

  // MARK: - Sessions

  private func handleProfileSessionRecords(_ sessions: [ProfileSessionRecord]) {
    guard let context = modelContext else {
      Log.info("No model context available", category: .sync)
      return
    }

    let deviceId = SharedData.deviceSyncId.uuidString

    for session in sessions {
      applySessionState(session, context: context, deviceId: deviceId)
    }
  }

  func handleSessionSync(for profileId: UUID) async {
    guard let context = modelContext else {
      Log.info("No model context available", category: .sync)
      return
    }

    let deviceId = SharedData.deviceSyncId.uuidString

    let result = await SessionSyncService.shared.fetchSession(profileId: profileId)

    switch result {
    case .found(let session):
      applySessionState(session, context: context, deviceId: deviceId)

    case .notFound:
      if let active = sessionController.activeSession,
        active.blockedProfile.id == profileId
      {
        Log.info("No remote session, stopping local", category: .sync)
        sessionController.stopRemoteSession(context: context, profileId: profileId)
      }

    case .error(let error):
      Log.info("Error fetching session - \(error)", category: .sync)
    }
  }

  private func applySessionState(
    _ session: ProfileSessionRecord,
    context: ModelContext,
    deviceId: String
  ) {
    let profileId = session.profileId

    if session.lastModifiedBy == deviceId {
      Log.info("Ignoring our own update for \(profileId)", category: .sync)
      return
    }

    let localActive = sessionController.activeSession?.blockedProfile.id == profileId

    if session.isActive && !localActive {
      Log.info("Remote session active, starting locally", category: .sync)

      if let startTime = session.startTime {
        sessionController.startRemoteSession(
          context: context,
          profileId: profileId,
          sessionId: UUID(),
          startTime: startTime
        )
        remoteTriggeredProfileIds.insert(profileId)
      }

    } else if !session.isActive && localActive {
      Log.info("Remote session stopped, stopping locally", category: .sync)
      sessionController.stopRemoteSession(context: context, profileId: profileId)
      remoteTriggeredProfileIds.remove(profileId)
    }
  }

  func syncAllProfileSessions() async {
    guard let context = modelContext else { return }

    do {
      let profiles = try BlockedProfiles.fetchProfiles(in: context)
      for profile in profiles {
        await handleSessionSync(for: profile.id)
      }
    } catch {
      Log.info("Error fetching profiles for sync - \(error)", category: .sync)
    }
  }

  // MARK: - Reset

  private func handleSyncReset(clearAppSelections: Bool) {
    guard let context = modelContext else {
      Log.info("No model context available", category: .sync)
      return
    }

    SharedData.clearLocallyRemovedProfileIdsForSync()

    if clearAppSelections {
      do {
        let profiles = try BlockedProfiles.fetchProfiles(in: context)
        for profile in profiles {
          profile.needsAppSelection = true
          profile.selectedActivity = .init()
          BlockedProfiles.updateSnapshot(for: profile)
        }
        try context.save()
        Log.info("Cleared app selections for all profiles", category: .sync)
      } catch {
        Log.info("Error clearing app selections - \(error)", category: .sync)
      }
    }

    let previousTask = pushTask
    pushTask = Task {
      await previousTask?.value
      await rePushLocalSyncedData(context: context)

      await syncManager.performFullSync()
    }
  }

  private func rePushLocalSyncedData(context: ModelContext) async {
    do {
      let profiles = try BlockedProfiles.fetchProfiles(in: context)
      for profile in profiles where !profile.isNewerSchemaVersion {
        do {
          try await syncManager.pushProfile(profile)
          Log.info("Re-pushed profile '\(profile.name)' after reset", category: .sync)
        } catch {
          Log.error(
            "Failed to re-push profile '\(profile.name)' after reset: \(error.localizedDescription)",
            category: .sync)
        }
      }
    } catch {
      Log.info("Error re-pushing data after reset - \(error)", category: .sync)
    }
  }

  // MARK: - Public push / delete

  func pushProfile(_ profile: BlockedProfiles) {
    guard syncManager.isEnabled else { return }
    guard !profile.isNewerSchemaVersion else {
      Log.info("Skipping push for newer schema profile '\(profile.name)'", category: .sync)
      return
    }
    guard let context = modelContext else {
      Log.info("No model context available for push", category: .sync)
      return
    }

    profile.syncVersion += 1
    do {
      try context.save()
    } catch {
      Log.error(
        "Failed to save profile version increment before push: \(error.localizedDescription)",
        category: .sync)
      return
    }

    let previousTask = pushTask
    pushTask = Task {
      await previousTask?.value
      do {
        try await syncManager.pushProfile(profile)
      } catch {
        Log.error(
          "Failed to push profile '\(profile.name)': \(error.localizedDescription)",
          category: .sync)
      }
    }
  }

  /// Records a profile as removed on this device only. The iCloud record stays so other devices keep the profile.
  func deleteProfileFromSync(_ profileId: UUID) {
    guard syncManager.isEnabled else { return }

    SharedData.registerProfileRemovedLocallyFromSync(profileId)
    Log.info(
      "Profile \(profileId) removed locally; left in iCloud for other devices", category: .sync)
  }
}

extension SyncCoordinator: SyncEventDelegate {
  func didReceiveSyncedProfiles(_ profiles: [SyncedProfile], remoteProfileIds: Set<UUID>) {
    handleSyncedProfiles(profiles, remoteProfileIds: remoteProfileIds)
  }

  func didReceiveSessionRecords(_ sessions: [ProfileSessionRecord]) {
    handleProfileSessionRecords(sessions)
  }

  func didReceiveEmergencyState(_ state: SyncedEmergencyState) {
    if state.updatedAt <= EmergencyStateSync.localModificationDate {
      return
    }
    EmergencyStateSync.applyFromRemote(state)
    StrategyManager.shared.refreshEmergencyStateFromDefaults()
    Log.info("Applied emergency unlock state from iCloud", category: .sync)
  }

  func didReceiveSyncReset(clearAppSelections: Bool) {
    handleSyncReset(clearAppSelections: clearAppSelections)
  }

  func didRequestLocalDataPush() {
    pushLocalData()
  }
}
