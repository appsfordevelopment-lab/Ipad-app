import Foundation

/// Shared constants and rules for the active-session shield monitor (main app + extension).
enum ActiveSessionShieldTiming {
  /// Prefix for `DeviceActivityName` and `TimerActivityUtil` routing (`"\(activityId):profileUUID"`).
  static let activityId = "ActiveSessionShieldActivity"

  /// Each window triggers `intervalDidStart` / `intervalDidEnd`; when the session is still
  /// active, the extension reschedules another window so shields can be re-applied after
  /// Managed Settings are cleared while the main app is not running.
  static let keepaliveHours = 6
}

enum ActiveSessionShieldState {
  /// Mirrors main-app logic: shields should be off during an active break or an in-progress pause.
  static func shouldApplyShields(
    session: SharedData.SessionSnapshot,
    profile: SharedData.ProfileSnapshot,
    now: Date = Date()
  ) -> Bool {
    if session.endTime != nil {
      return false
    }

    if profile.enableBreaks,
      session.breakStartTime != nil,
      session.breakEndTime == nil
    {
      return false
    }

    if let pauseStart = session.pauseStartTime, session.pauseEndTime == nil {
      let pauseSeconds = pauseDurationSeconds(strategyData: profile.strategyData)
      if now.timeIntervalSince(pauseStart) < pauseSeconds {
        return false
      }
    }

    return true
  }

  private static func pauseDurationSeconds(strategyData: Data?) -> TimeInterval {
    guard let strategyData else {
      return TimeInterval(15 * 60)
    }
    struct PausePayload: Codable {
      var pauseDurationInMinutes: Int
    }
    if let payload = try? JSONDecoder().decode(PausePayload.self, from: strategyData) {
      return TimeInterval(max(payload.pauseDurationInMinutes, 1) * 60)
    }
    return TimeInterval(15 * 60)
  }
}
