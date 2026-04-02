//
//  DeviceActivityMonitorExtension.swift
//  Tyme Boxed
//
//  Created by Ali Waseem on 2025-05-27.
//

import DeviceActivity
import OSLog

private let log = Logger(
  subsystem: "com.timeboxed.monitor",
  category: "DeviceActivity"
)

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override init() {
    super.init()
  }

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)

    log.info("intervalDidStart for activity: \(activity.rawValue)")
    TimerActivityUtil.startTimerActivity(for: activity)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    log.info("intervalDidEnd for activity: \(activity.rawValue)")
    TimerActivityUtil.stopTimerActivity(for: activity)
  }

  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)

    log.info("intervalWillEndWarning for activity: \(activity.rawValue)")
    // Only pause activities pass `warningTime` (see DeviceActivityCenterUtil). Calling
    // stopTimerActivity here for schedule/break/strategy would end shields before
    // intervalDidEnd.
    guard TimerActivityUtil.usesIntervalWillEndWarning(for: activity) else {
      return
    }
    TimerActivityUtil.stopTimerActivity(for: activity)
  }
}
