import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

class DeviceActivityCenterUtil {
  static func scheduleTimerActivity(for profile: BlockedProfiles) {
    // Only schedule if the schedule is active
    guard let schedule = profile.schedule else { return }

    let center = DeviceActivityCenter()
    let scheduleTimerActivity = ScheduleTimerActivity()
    let deviceActivityName = scheduleTimerActivity.getDeviceActivityName(
      from: profile.id.uuidString)

    // If the schedule is not active, remove any existing schedule
    if !schedule.isActive {
      stopActivities(for: [deviceActivityName], with: center)
      return
    }

    let (intervalStart, intervalEnd) = scheduleTimerActivity.getScheduleInterval(from: schedule)
    let deviceActivitySchedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: true,
    )

    do {
      // startMonitoring replaces an existing schedule for this activity name. Do not call
      // stopMonitoring first: if startMonitoring throws, stopping first would leave no
      // monitoring while SwiftData still has an active schedule (shows "schedule destroyed").
      try center.startMonitoring(deviceActivityName, during: deviceActivitySchedule)
      print("Scheduled restrictions from \(intervalStart) to \(intervalEnd) daily")
      invokeScheduleTimerStartFromHost(for: profile)
    } catch {
      print("Failed to start monitoring: \(error.localizedDescription)")
    }
  }

  static func startBreakTimerActivity(for profile: BlockedProfiles) {
    let center = DeviceActivityCenter()
    let breakTimerActivity = BreakTimerActivity()
    let deviceActivityName = breakTimerActivity.getDeviceActivityName(from: profile.id.uuidString)

    let (intervalStart, intervalEnd) = absoluteIntervalFromNow(
      minutes: profile.breakTimeInMinutes)
    let deviceActivitySchedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: false,
    )

    do {
      // Remove any existing schedule and create a new one
      stopActivities(for: [deviceActivityName], with: center)
      try center.startMonitoring(deviceActivityName, during: deviceActivitySchedule)
      print("Scheduled break timer activity from \(intervalStart) to \(intervalEnd)")
      invokeBreakTimerStartFromHost(forProfileId: profile.id.uuidString)
    } catch {
      print("Failed to start break timer activity: \(error.localizedDescription)")
    }
  }

  static func startStrategyTimerActivity(for profile: BlockedProfiles) {
    guard let strategyData = profile.strategyData else {
      print("No strategy data found for profile: \(profile.id.uuidString)")
      return
    }
    let timerData = StrategyTimerData.toStrategyTimerData(from: strategyData)

    let center = DeviceActivityCenter()
    let strategyTimerActivity = StrategyTimerActivity()
    let deviceActivityName = strategyTimerActivity.getDeviceActivityName(
      from: profile.id.uuidString)

    let (intervalStart, intervalEnd) = absoluteIntervalFromNow(
      minutes: timerData.durationInMinutes)

    let deviceActivitySchedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: false,
    )

    do {
      // Remove any existing activity and create a new one
      stopActivities(for: [deviceActivityName], with: center)
      try center.startMonitoring(deviceActivityName, during: deviceActivitySchedule)
      print("Scheduled strategy timer activity from \(intervalStart) to \(intervalEnd)")
      invokeStrategyTimerStartFromHost(forProfileId: profile.id.uuidString)
    } catch {
      print("Failed to start strategy timer activity: \(error.localizedDescription)")
    }
  }

  static func removeScheduleTimerActivities(for profile: BlockedProfiles) {
    let scheduleTimerActivity = ScheduleTimerActivity()
    let deviceActivityName = scheduleTimerActivity.getDeviceActivityName(
      from: profile.id.uuidString)
    stopActivities(for: [deviceActivityName])
  }

  static func removeScheduleTimerActivities(for activity: DeviceActivityName) {
    stopActivities(for: [activity])
  }

  static func removeAllBreakTimerActivities() {
    let center = DeviceActivityCenter()
    let activities = center.activities
    let breakTimerActivity = BreakTimerActivity()
    let breakTimerActivities = breakTimerActivity.getAllBreakTimerActivities(from: activities)
    stopActivities(for: breakTimerActivities, with: center)
  }

  static func removeBreakTimerActivity(for profile: BlockedProfiles) {
    let breakTimerActivity = BreakTimerActivity()
    let deviceActivityName = breakTimerActivity.getDeviceActivityName(from: profile.id.uuidString)
    stopActivities(for: [deviceActivityName])
  }

  static func removeAllStrategyTimerActivities() {
    let center = DeviceActivityCenter()
    let activities = center.activities
    let strategyTimerActivity = StrategyTimerActivity()
    let strategyTimerActivities = strategyTimerActivity.getAllStrategyTimerActivities(
      from: activities)
    stopActivities(for: strategyTimerActivities, with: center)
  }

  static func startPauseTimerActivity(for profile: BlockedProfiles) {
    guard let strategyData = profile.strategyData else {
      print("No strategy data found for pause timer in profile: \(profile.id.uuidString)")
      return
    }
    let pauseData = StrategyPauseTimerData.toStrategyPauseTimerData(from: strategyData)
    let minutes = pauseData.pauseDurationInMinutes

    let center = DeviceActivityCenter()
    let pauseTimerActivity = PauseTimerActivity()
    let deviceActivityName = pauseTimerActivity.getDeviceActivityName(
      from: profile.id.uuidString)

    let (intervalStart, intervalEnd, warningTime) =
      getPauseTimeIntervalStartAndEnd(from: minutes)

    let deviceActivitySchedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: false,
      warningTime: warningTime
    )

    do {
      stopActivities(for: [deviceActivityName])
      try center.startMonitoring(deviceActivityName, during: deviceActivitySchedule)
      print("Scheduled pause timer activity for \(minutes) min (DeviceActivity)")
      invokePauseTimerStartFromHost(forProfileId: profile.id.uuidString)
    } catch {
      print("Failed to start pause timer activity: \(error.localizedDescription)")
    }
  }

  static func removePauseTimerActivity(for profile: BlockedProfiles) {
    removePauseTimerActivity(forProfileId: profile.id.uuidString)
  }

  static func removePauseTimerActivity(forProfileId profileId: String) {
    let pauseTimerActivity = PauseTimerActivity()
    let deviceActivityName = pauseTimerActivity.getDeviceActivityName(
      from: profileId)
    stopActivities(for: [deviceActivityName])
  }

  static func removeAllPauseTimerActivities() {
    let center = DeviceActivityCenter()
    let activities = center.activities
    let pauseTimerActivity = PauseTimerActivity()
    let pauseTimerActivities = pauseTimerActivity.getAllPauseTimerActivities(from: activities)
    stopActivities(for: pauseTimerActivities, with: center)
  }

  static func getActiveScheduleTimerActivity(for profile: BlockedProfiles) -> DeviceActivityName? {
    let center = DeviceActivityCenter()
    let scheduleTimerActivity = ScheduleTimerActivity()
    let activities = center.activities

    return activities.first(where: {
      $0 == scheduleTimerActivity.getDeviceActivityName(from: profile.id.uuidString)
    })
  }

  static func getDeviceActivities() -> [DeviceActivityName] {
    let center = DeviceActivityCenter()
    return center.activities
  }

  /// Starts (or replaces) Device Activity that re-applies shields while a session is active.
  static func startActiveSessionShieldMonitor(for profile: BlockedProfiles) {
    let profileId = profile.id.uuidString
    ActiveSessionShieldTimerActivity.startOrRestartMonitor(forProfileId: profileId)
    invokeActiveSessionShieldStartFromHost(forProfileId: profileId)
  }

  static func removeActiveSessionShieldMonitor(for profileID: UUID) {
    ActiveSessionShieldTimerActivity.removeMonitor(forProfileId: profileID.uuidString)
  }

  // MARK: - Host-app mirror of extension (`DeviceActivityMonitor.intervalDidStart`)

  /// Open-source Foqos flow relies on `DeviceActivityMonitor` calling `TimerActivityUtil`
  /// ([`awaseem/foqos`](https://github.com/awaseem/foqos)). On some iOS versions `intervalDidStart`
  /// does not run when `startMonitoring` succeeds, so shields never apply once the host suspends.
  /// Run the same `TimerActivity.start` from the app immediately after scheduling.
  private static func invokeActiveSessionShieldStartFromHost(forProfileId profileId: String) {
    guard let snapshot = SharedData.snapshot(for: profileId) else { return }
    ActiveSessionShieldTimerActivity().start(for: snapshot)
  }

  private static func invokeStrategyTimerStartFromHost(forProfileId profileId: String) {
    guard let snapshot = SharedData.snapshot(for: profileId) else { return }
    StrategyTimerActivity().start(for: snapshot)
  }

  private static func invokeBreakTimerStartFromHost(forProfileId profileId: String) {
    guard let snapshot = SharedData.snapshot(for: profileId) else { return }
    BreakTimerActivity().start(for: snapshot)
  }

  private static func invokePauseTimerStartFromHost(forProfileId profileId: String) {
    guard let snapshot = SharedData.snapshot(for: profileId) else { return }
    PauseTimerActivity().start(for: snapshot)
  }

  private static func invokeScheduleTimerStartFromHost(for profile: BlockedProfiles) {
    BlockedProfiles.updateSnapshot(for: profile)
    guard let snapshot = SharedData.snapshot(for: profile.id.uuidString) else { return }
    ScheduleTimerActivity().start(for: snapshot)
  }

  private static func stopActivities(
    for activities: [DeviceActivityName], with center: DeviceActivityCenter? = nil
  ) {
    let center = center ?? DeviceActivityCenter()

    if activities.isEmpty {
      // No activities to stop
      print("No activities to stop")
      return
    }

    center.stopMonitoring(activities)
  }

  /// Device Activity schedules that use clock times without calendar fields (e.g. start 00:00)
  /// are often already "inside" the interval when monitoring begins, so `intervalDidStart` never
  /// runs and the monitor extension cannot re-apply Managed Settings after app termination.
  /// Use full date components from **now** so the interval truly begins at `startMonitoring`.
  private static func absoluteIntervalFromNow(minutes: Int) -> (
    intervalStart: DateComponents, intervalEnd: DateComponents
  ) {
    let calendar = Calendar.current
    let now = Date()
    let effectiveMinutes = max(minutes, 1)
    let intervalStart = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now
    )
    let endDate =
      calendar.date(byAdding: .minute, value: effectiveMinutes, to: now) ?? now.addingTimeInterval(
        TimeInterval(effectiveMinutes * 60))
    let intervalEnd = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: endDate
    )
    return (intervalStart: intervalStart, intervalEnd: intervalEnd)
  }

  /// DeviceActivitySchedule requires minimum 15 min interval. For shorter pauses,
  /// use 15 min interval + warningTime so intervalWillEndWarning fires at actual pause end.
  private static func getPauseTimeIntervalStartAndEnd(from minutes: Int) -> (
    intervalStart: DateComponents,
    intervalEnd: DateComponents,
    warningTime: DateComponents?
  ) {
    let calendar = Calendar.current
    let now = Date()
    let effectiveMinutes = max(minutes, 1)

    let intervalMinutes = max(effectiveMinutes, 15)

    guard let intervalEndDate = calendar.date(
      byAdding: .minute,
      value: intervalMinutes,
      to: now
    ) else {
      let (start, end) = absoluteIntervalFromNow(minutes: max(intervalMinutes, 1))
      return (intervalStart: start, intervalEnd: end, warningTime: nil)
    }

    let intervalStart = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now
    )
    let intervalEnd = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: intervalEndDate
    )

    let warningTime: DateComponents? =
      effectiveMinutes < 15
      ? DateComponents(minute: intervalMinutes - effectiveMinutes)  // re-block at pause end
      : nil

    return (intervalStart: intervalStart, intervalEnd: intervalEnd, warningTime: warningTime)
  }
}
