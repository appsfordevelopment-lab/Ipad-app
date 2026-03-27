import FamilyControls
import SwiftUI

/// Vertical list of `BlockedProfileCard` rows (same visuals as the carousel, without horizontal paging).
struct BlockedProfileCardList: View {
  let profiles: [BlockedProfiles]
  let isBlocking: Bool
  let isBreakAvailable: Bool
  let isBreakActive: Bool
  let isPauseActive: Bool
  let activeSessionProfileId: UUID?
  let elapsedTime: TimeInterval

  var onStartTapped: (BlockedProfiles) -> Void
  var onStopTapped: (BlockedProfiles) -> Void
  var onEditTapped: (BlockedProfiles) -> Void
  var onStatsTapped: (BlockedProfiles) -> Void
  var onBreakTapped: (BlockedProfiles) -> Void
  var onAppSelectionTapped: ((BlockedProfiles) -> Void)?
  var onEmergencyTapped: () -> Void

  private var titleMessage: String {
    isBlocking ? "Active Profile" : "Profile"
  }

  init(
    profiles: [BlockedProfiles],
    isBlocking: Bool,
    isBreakAvailable: Bool,
    isBreakActive: Bool,
    isPauseActive: Bool = false,
    activeSessionProfileId: UUID?,
    elapsedTime: TimeInterval,
    onStartTapped: @escaping (BlockedProfiles) -> Void,
    onStopTapped: @escaping (BlockedProfiles) -> Void,
    onEditTapped: @escaping (BlockedProfiles) -> Void,
    onStatsTapped: @escaping (BlockedProfiles) -> Void,
    onBreakTapped: @escaping (BlockedProfiles) -> Void,
    onAppSelectionTapped: ((BlockedProfiles) -> Void)? = nil,
    onEmergencyTapped: @escaping () -> Void
  ) {
    self.profiles = profiles
    self.isBlocking = isBlocking
    self.isBreakAvailable = isBreakAvailable
    self.isBreakActive = isBreakActive
    self.isPauseActive = isPauseActive
    self.activeSessionProfileId = activeSessionProfileId
    self.elapsedTime = elapsedTime
    self.onStartTapped = onStartTapped
    self.onStopTapped = onStopTapped
    self.onEditTapped = onEditTapped
    self.onStatsTapped = onStatsTapped
    self.onBreakTapped = onBreakTapped
    self.onAppSelectionTapped = onAppSelectionTapped
    self.onEmergencyTapped = onEmergencyTapped
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(
        titleMessage,
        buttonText: isBlocking ? "Emergency" : nil,
        buttonAction: isBlocking ? onEmergencyTapped : nil,
        buttonIcon: isBlocking ? "exclamationmark.triangle.fill" : nil,
        buttonBackgroundColor: isBlocking ? Color.emergencyLightRed : nil,
        buttonTextColor: isBlocking ? .white : nil
      )
      .padding(.horizontal, 16)

      LazyVStack(spacing: 16) {
        ForEach(profiles, id: \.id) { profile in
          BlockedProfileCard(
            profile: profile,
            isActive: profile.id == activeSessionProfileId,
            isBreakAvailable: isBreakAvailable,
            isBreakActive: isBreakActive,
            elapsedTime: elapsedTime,
            onStartTapped: { onStartTapped(profile) },
            onStopTapped: { onStopTapped(profile) },
            onEditTapped: { onEditTapped(profile) },
            onStatsTapped: { onStatsTapped(profile) },
            onBreakTapped: { onBreakTapped(profile) },
            onAppSelectionTapped: onAppSelectionTapped.map { fn in { fn(profile) } },
            isPauseActive: isPauseActive
          )
        }
      }
      .padding(.horizontal, 16)
    }
  }
}
