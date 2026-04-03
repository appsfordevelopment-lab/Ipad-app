import DeviceActivity
import Foundation
import OSLog

private let log = Logger(
  subsystem: "com.timeboxed.monitor",
  category: ActiveSessionShieldTiming.activityId)

/// Re-applies Managed Settings from the app group while a blocking session is active, so blocking
/// survives app suspension, termination, and intermittent Managed Settings clears.
class ActiveSessionShieldTimerActivity: TimerActivity {
  static var id: String { ActiveSessionShieldTiming.activityId }

  private let appBlocker = AppBlockerUtil()

  func getDeviceActivityName(from profileId: String) -> DeviceActivityName {
    DeviceActivityName(rawValue: "\(Self.id):\(profileId)")
  }

  func start(for profile: SharedData.ProfileSnapshot) {
    let profileId = profile.id.uuidString

    guard let session = SharedData.getActiveSharedSession(),
      session.blockedProfileId == profile.id,
      session.endTime == nil
    else {
      log.info("start: no matching active session for \(profileId, privacy: .public)")
      return
    }

    guard ActiveSessionShieldState.shouldApplyShields(session: session, profile: profile) else {
      log.info("start: skip (break or pause) for \(profileId, privacy: .public)")
      return
    }

    log.info("start: re-applying restrictions for \(profileId, privacy: .public)")
    appBlocker.activateRestrictions(for: profile)
  }

  func stop(for profile: SharedData.ProfileSnapshot) {
    let profileId = profile.id.uuidString

    guard let session = SharedData.getActiveSharedSession(),
      session.blockedProfileId == profile.id,
      session.endTime == nil
    else {
      log.info("stop: session ended or mismatch for \(profileId, privacy: .public)")
      return
    }

    log.info("stop: rescheduling keepalive for \(profileId, privacy: .public)")
    Self.startOrRestartMonitor(forProfileId: profileId)
  }

  static func startOrRestartMonitor(forProfileId profileId: String) {
    let calendar = Calendar.current
    let now = Date()
    let hours = ActiveSessionShieldTiming.keepaliveHours

    let intervalStart = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now
    )
    let endDate =
      calendar.date(byAdding: .hour, value: max(hours, 1), to: now)
      ?? now.addingTimeInterval(TimeInterval(max(hours, 1) * 3600))
    let intervalEnd = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: endDate
    )

    let name = DeviceActivityName(rawValue: "\(ActiveSessionShieldTiming.activityId):\(profileId)")
    let schedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: false
    )

    let center = DeviceActivityCenter()
    do {
      center.stopMonitoring([name])
      try center.startMonitoring(name, during: schedule)
    } catch {
      log.error(
        "startOrRestartMonitor failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  static func removeMonitor(forProfileId profileId: String) {
    let name = DeviceActivityName(rawValue: "\(ActiveSessionShieldTiming.activityId):\(profileId)")
    DeviceActivityCenter().stopMonitoring([name])
  }

  static func removeAllMonitors() {
    let center = DeviceActivityCenter()
    let prefix = "\(ActiveSessionShieldTiming.activityId):"
    let toStop = center.activities.filter { $0.rawValue.hasPrefix(prefix) }
    guard !toStop.isEmpty else { return }
    center.stopMonitoring(toStop)
  }
}
