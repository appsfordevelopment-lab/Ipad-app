import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.openURL) var openURL

  @Environment(\.scenePhase) private var scenePhase

  @EnvironmentObject var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject var strategyManager: StrategyManager
  @EnvironmentObject var navigationManager: NavigationManager
  @EnvironmentObject var ratingManager: RatingManager
  @EnvironmentObject private var profileSyncManager: ProfileSyncManager

  @ObservedObject private var syncConflictManager = SyncConflictManager.shared

  @State private var selectedMainTab: MainTab = .profile

  // Profile management
  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .reverse),
  ]) private
    var profiles: [BlockedProfiles]
  // Edit profile
  @State private var profileToEdit: BlockedProfiles? = nil

  // Stats sheet
  @State private var profileToShowStats: BlockedProfiles? = nil

  // Emergency View
  @State private var showEmergencyView = false

  // Debug mode
  @State private var showingDebugMode = false

  @State private var profileForAppSelection: BlockedProfiles?

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime != nil },
    sort: \BlockedProfileSession.endTime,
    order: .reverse
  ) private var recentCompletedSessions: [BlockedProfileSession]

  // Alerts
  @State private var showingAlert = false
  @State private var alertTitle = ""
  @State private var alertMessage = ""

  // Intro sheet
  @AppStorage("showIntroScreen") private var showIntroScreen = true

  var isBlocking: Bool {
    return strategyManager.isBlocking
  }

  var activeSessionProfileId: UUID? {
    return strategyManager.activeSession?.blockedProfile.id
  }

  var isBreakAvailable: Bool {
    return strategyManager.isBreakAvailable
  }

  var isBreakActive: Bool {
    return strategyManager.isBreakActive
  }

  var body: some View {
    Group {
      switch selectedMainTab {
      case .activity:
        activityTabContent
          .refreshable {
            await refreshSyncedContent()
          }
      case .profile:
        profileTabContent
          .refreshable {
            await refreshSyncedContent()
          }
      case .settings:
        SettingsView(showsDismissButton: false)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      MainTabBar(selection: $selectedMainTab)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    .padding(.top, 1)
    .frame(
      minWidth: 0,
      maxWidth: .infinity,
      minHeight: 0,
      maxHeight: .infinity,
      alignment: .topLeading
    )
    .onChange(of: navigationManager.profileId) { _, newValue in
      if let profileId = newValue, let url = navigationManager.link {
        toggleSessionFromDeeplink(profileId, link: url)
        navigationManager.clearNavigation()
      }
    }
    .onChange(of: navigationManager.navigateToProfileId) { _, newValue in
      if newValue != nil {
        navigationManager.clearNavigation()
        selectedMainTab = .profile
      }
    }
    .onChange(of: requestAuthorizer.isAuthorized) { _, newValue in
      if newValue {
        showIntroScreen = false
      } else {
        showIntroScreen = true
      }
    }
    .onChange(of: profiles) { oldValue, newValue in
      if !newValue.isEmpty {
        loadApp()
      }
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      if newPhase == .active {
        loadApp()
      } else {
        if oldPhase == .active {
          strategyManager.reapplyShieldsWhenLeavingActive(context: context)
        }
        if newPhase == .background {
          unloadApp()
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .strategyManagerPauseEnded)) { _ in
      loadApp()
    }
    .onReceive(strategyManager.$errorMessage) { errorMessage in
      if let message = errorMessage {
        showErrorAlert(message: message)
      }
    }
    .onAppear {
      onAppearApp()
    }
    .fullScreenCover(isPresented: $showIntroScreen) {
      IntroView {
        requestAuthorizer.requestAuthorization {
          showIntroScreen = false
        }
      }.interactiveDismissDisabled()
    }
    .sheet(item: $profileToEdit) { profile in
      BlockedProfileView(profile: profile)
    }
    .sheet(item: $profileToShowStats) { profile in
      ProfileInsightsView(profile: profile)
    }
    .sheet(isPresented: $strategyManager.showCustomStrategyView) {
      BlockingStrategyActionView(
        customView: strategyManager.customStrategyView
      )
      .presentationDetents([.medium])
    }
    .sheet(isPresented: $showEmergencyView) {
      EmergencyView()
        .presentationDetents([.height(350)])
    }
    .sheet(isPresented: $showingDebugMode) {
      DebugView()
    }
    .sheet(item: $profileForAppSelection) { profile in
      NavigationStack {
        AppSelectionPrompt(profile: profile)
          .navigationTitle("App Selection")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") {
                profileForAppSelection = nil
              }
            }
          }
      }
    }
    .alert(alertTitle, isPresented: $showingAlert) {
      Button("OK", role: .cancel) { dismissAlert() }
    } message: {
      Text(alertMessage)
    }
  }

  private var mainHeader: some View {
    HStack(alignment: .center) {
      AppTitle()
      Spacer()
    }
    .padding(.trailing, 16)
    .padding(.top, 16)
  }

  private var profileTabContent: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 30) {
        mainHeader

        AuthorizationCallout(
          authorizationStatus: requestAuthorizer.getAuthorizationStatus(),
          onAuthorizationHandler: {
            requestAuthorizer.requestAuthorization()
          }
        )
        .padding(.horizontal, 16)

        if syncConflictManager.shouldShowOlderDeviceBanner {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            Text(syncConflictManager.conflictMessage)
              .font(.subheadline)
            Spacer(minLength: 0)
            Button("Dismiss") {
              syncConflictManager.dismissBanner()
            }
            .font(.caption)
          }
          .padding(12)
          .background(Color.orange.opacity(0.12))
          .cornerRadius(12)
          .padding(.horizontal, 16)
        }

        if syncConflictManager.shouldShowNewerVersionBanner {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundStyle(.blue)
            Text(syncConflictManager.newerVersionMessage)
              .font(.subheadline)
            Spacer(minLength: 0)
            Button("Dismiss") {
              syncConflictManager.dismissBanner()
            }
            .font(.caption)
          }
          .padding(12)
          .background(Color.blue.opacity(0.12))
          .cornerRadius(12)
          .padding(.horizontal, 16)
        }

        if profiles.isEmpty {
          IphoneCompanionSyncCard()
            .padding(.horizontal, 16)
        }

        if !profiles.isEmpty {
          BlockedProfileCardList(
            profiles: profiles,
            isBlocking: isBlocking,
            isBreakAvailable: isBreakAvailable,
            isBreakActive: isBreakActive,
            isPauseActive: strategyManager.isPauseActive,
            activeSessionProfileId: activeSessionProfileId,
            elapsedTime: strategyManager.elapsedTime,
            onStartTapped: { profile in
              strategyButtonPress(profile)
            },
            onStopTapped: { profile in
              strategyButtonPress(profile)
            },
            onEditTapped: { profile in
              profileToEdit = profile
            },
            onStatsTapped: { profile in
              profileToShowStats = profile
            },
            onBreakTapped: { _ in
              strategyManager.toggleBreak(context: context)
            },
            onAppSelectionTapped: { profile in
              profileForAppSelection = profile
            },
            onEmergencyTapped: {
              showEmergencyView = true
            },
          )
        }

        VersionFooter(
          profileIsActive: isBlocking,
          tapProfileDebugHandler: {
            showingDebugMode = true
          }
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 15)
      }
    }
  }

  private var activityTabContent: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 30) {
        mainHeader

        AuthorizationCallout(
          authorizationStatus: requestAuthorizer.getAuthorizationStatus(),
          onAuthorizationHandler: {
            requestAuthorizer.requestAuthorization()
          }
        )
        .padding(.horizontal, 16)

        BlockedSessionsHabitTracker(
          sessions: recentCompletedSessions
        )
        .padding(.horizontal, 16)
      }
    }
  }

  private func toggleSessionFromDeeplink(_ profileId: String, link: URL) {
    strategyManager
      .toggleSessionFromDeeplink(profileId, url: link, context: context)
  }

  private func strategyButtonPress(_ profile: BlockedProfiles) {
    strategyManager
      .toggleBlocking(context: context, activeProfile: profile)

    ratingManager.incrementLaunchCount()
  }

  private func refreshSyncedContent() async {
    if profileSyncManager.isEnabled {
      await profileSyncManager.performFullSync()
    }
    await MainActor.run {
      loadApp()
    }
  }

  private func loadApp() {
    strategyManager.loadActiveSession(context: context)
    strategyManager.resyncAllScheduleMonitoringWithDeviceActivity(context: context)
    SyncCoordinator.shared.applyIPadNFCPauseFocusAdaptationsIfNeeded(in: context)
  }

  private func onAppearApp() {
    strategyManager.loadActiveSession(context: context)
    strategyManager.cleanUpGhostSchedules(context: context)
    strategyManager.resyncAllScheduleMonitoringWithDeviceActivity(context: context)
  }

  private func unloadApp() {
    strategyManager.stopTimer()
    if strategyManager.isPauseActive {
      TimersUtil().reschedulePauseEndWhenEnteringBackground()
    }
  }

  private func showErrorAlert(message: String) {
    alertTitle = "Whoops"
    alertMessage = message
    showingAlert = true
  }

  private func dismissAlert() {
    showingAlert = false
  }
}

#Preview {
  HomeView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(TipManager())
    .environmentObject(NavigationManager())
    .environmentObject(StrategyManager())
    .environmentObject(RatingManager())
    .environmentObject(ProfileSyncManager.shared)
    .environmentObject(ThemeManager.shared)
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
    .onAppear {
      UserDefaults(suiteName: "preview")!.set(
        false,
        forKey: "showIntroScreen"
      )
    }
}
