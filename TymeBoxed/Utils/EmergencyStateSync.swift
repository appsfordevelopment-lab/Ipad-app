import Foundation

/// Persists emergency-unblock counters in `UserDefaults` (same keys as `StrategyManager` @AppStorage)
/// and tracks modification time for CloudKit last-write-wins sync.
enum EmergencyStateSync {
  static let remainingKey = "emergencyUnblocksRemaining"
  static let resetPeriodWeeksKey = "emergencyUnblocksResetPeriodInWeeks"
  static let lastResetTimestampKey = "lastEmergencyUnblocksResetDate"
  /// Wall-clock time when local values were last changed or merged from iCloud (for conflict handling).
  private static let modificationDateKey = "emergencyUnblocksSyncModificationDate"

  private static let defaults = UserDefaults.standard

  static var localModificationDate: Date {
    let t = defaults.double(forKey: modificationDateKey)
    if t <= 0 { return .distantPast }
    return Date(timeIntervalSinceReferenceDate: t)
  }

  static func markLocallyModifiedNow() {
    defaults.set(Date().timeIntervalSinceReferenceDate, forKey: modificationDateKey)
    defaults.synchronize()
  }

  static func markMergedFromRemote(updatedAt: Date) {
    defaults.set(updatedAt.timeIntervalSinceReferenceDate, forKey: modificationDateKey)
    defaults.synchronize()
  }

  static func readForCloudKit(originDeviceId: String) -> SyncedEmergencyState {
    let remaining = defaults.object(forKey: remainingKey) as? Int ?? 3
    let weeks = defaults.object(forKey: resetPeriodWeeksKey) as? Int ?? 4
    let lastReset = defaults.double(forKey: lastResetTimestampKey)
    return SyncedEmergencyState(
      remainingUnblocks: remaining,
      resetPeriodWeeks: weeks,
      lastResetTimestamp: lastReset,
      updatedAt: Date(),
      originDeviceId: originDeviceId
    )
  }

  /// Writes remote state from iCloud. Does not bump local modification date beyond `state.updatedAt`.
  static func applyFromRemote(_ state: SyncedEmergencyState) {
    defaults.set(state.remainingUnblocks, forKey: remainingKey)
    defaults.set(state.resetPeriodWeeks, forKey: resetPeriodWeeksKey)
    defaults.set(state.lastResetTimestamp, forKey: lastResetTimestampKey)
    markMergedFromRemote(updatedAt: state.updatedAt)
  }
}
