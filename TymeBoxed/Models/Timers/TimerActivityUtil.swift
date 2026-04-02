import DeviceActivity
import OSLog

private let log = Logger(subsystem: "com.timeboxed.monitor", category: "TimerActivityUtil")

class TimerActivityUtil {
  static func startTimerActivity(for activity: DeviceActivityName) {
    let parts = getTimerParts(from: activity)

    guard let timerActivity = getTimerActivity(for: parts.deviceActivityId) else {
      log.error(
        "startTimerActivity: unknown deviceActivityId=\(parts.deviceActivityId, privacy: .public) rawValue=\(activity.rawValue, privacy: .public)"
      )
      return
    }

    guard let profile = getProfile(for: parts.profileId) else {
      log.error(
        "startTimerActivity: missing app group profile snapshot for profileId=\(parts.profileId, privacy: .public) rawValue=\(activity.rawValue, privacy: .public)"
      )
      return
    }

    timerActivity.start(for: profile)
  }

  static func stopTimerActivity(for activity: DeviceActivityName) {
    let parts = getTimerParts(from: activity)

    guard let timerActivity = getTimerActivity(for: parts.deviceActivityId) else {
      log.error(
        "stopTimerActivity: unknown deviceActivityId=\(parts.deviceActivityId, privacy: .public) rawValue=\(activity.rawValue, privacy: .public)"
      )
      return
    }

    guard let profile = getProfile(for: parts.profileId) else {
      log.error(
        "stopTimerActivity: missing app group profile snapshot for profileId=\(parts.profileId, privacy: .public) rawValue=\(activity.rawValue, privacy: .public)"
      )
      return
    }

    timerActivity.stop(for: profile)
  }

  /// True when `warningTime` was set on `DeviceActivitySchedule` (short pause workaround).
  static func usesIntervalWillEndWarning(for activity: DeviceActivityName) -> Bool {
    activity.rawValue.hasPrefix("\(PauseTimerActivity.id):")
  }

  private static func getTimerParts(from activity: DeviceActivityName) -> (
    deviceActivityId: String, profileId: String
  ) {
    let activityName = activity.rawValue
    let components = activityName.split(separator: ":")

    // For versions >= 1.24, the activity name format is "type:profileId"
    if components.count == 2 {
      return (deviceActivityId: String(components[0]), profileId: String(components[1]))
    }

    // For versions < 1.24, the activity name format is just "profileId" and only supports schedule timer activity
    // This is to support backward compatibility for older schedules
    return (deviceActivityId: ScheduleTimerActivity.id, profileId: activityName)
  }

  private static func getTimerActivity(for deviceActivityId: String) -> TimerActivity? {
    switch deviceActivityId {
    case ScheduleTimerActivity.id:
      return ScheduleTimerActivity()
    case BreakTimerActivity.id:
      return BreakTimerActivity()
    case StrategyTimerActivity.id:
      return StrategyTimerActivity()
    case PauseTimerActivity.id:
      return PauseTimerActivity()
    default:
      return nil
    }
  }

  private static func getProfile(for profileId: String) -> SharedData.ProfileSnapshot? {
    return SharedData.snapshot(for: profileId)
  }
}
