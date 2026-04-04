//
//  TymeBoxedApp.swift
//  Tyme Boxed
//
//  Created by Ali Waseem on 2024-10-06.
//

import AppIntents
import BackgroundTasks
import CloudKit
import SwiftData
import SwiftUI

/// Boots SwiftData on disk using named `ModelConfiguration`s, deletes corrupted stores
/// (`loadIssueModelContainer`), then falls back to a recovery name and in-memory store.
///
/// **CloudKit:** The app target has iCloud/CloudKit entitlements for custom sync code, but this stack must stay
/// **local-only** (`cloudKitDatabase: .none`). Otherwise SwiftData defaults to `.automatic` and tries to drive
/// the persistent store from CloudKit, which fails for this schema and surfaces as `loadIssueModelContainer`.
private enum SwiftDataStoreBootstrap {
  private static let primaryConfigurationName = "TymeBoxed"
  private static let recoveryConfigurationName = "TymeBoxed.recovery"

  /// Removes the store path plus SQLite WAL/SHM peers (SwiftData uses a SQLite backing store).
  private static func removeStoreArtifacts(at storeURL: URL) {
    let extras = [
      storeURL,
      URL(fileURLWithPath: storeURL.path + "-shm"),
      URL(fileURLWithPath: storeURL.path + "-wal"),
    ]
    for url in extras where FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static func makeOnDiskContainer(
    schema: Schema,
    configuration: ModelConfiguration
  ) throws -> ModelContainer {
    try ModelContainer(for: schema, configurations: [configuration])
  }

  private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
    do {
      let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
      )
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      Log.warning(
        "SwiftData in-memory (schema config) failed (\(error)); retrying with default configuration.",
        category: .app
      )
    }
    do {
      let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
      return try ModelContainer(
        for: BlockedProfiles.self,
        BlockedProfileSession.self,
        configurations: configuration
      )
    } catch {
      fatalError("Couldn’t create in-memory ModelContainer: \(error)")
    }
  }

  static func makeModelContainer() -> ModelContainer {
    let schema = Schema([
      BlockedProfiles.self,
      BlockedProfileSession.self,
    ])

    let primaryConfiguration = ModelConfiguration(
      primaryConfigurationName,
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .none
    )

    do {
      return try makeOnDiskContainer(schema: schema, configuration: primaryConfiguration)
    } catch {
      Log.warning(
        "SwiftData primary store failed (\(error)); deleting store files and retrying once.",
        category: .app
      )
      removeStoreArtifacts(at: primaryConfiguration.url)
    }

    do {
      return try makeOnDiskContainer(schema: schema, configuration: primaryConfiguration)
    } catch {
      Log.warning(
        "SwiftData retry on primary store failed (\(error)); trying recovery store.",
        category: .app
      )
    }

    let recoveryConfiguration = ModelConfiguration(
      recoveryConfigurationName,
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .none
    )
    removeStoreArtifacts(at: recoveryConfiguration.url)

    do {
      return try makeOnDiskContainer(schema: schema, configuration: recoveryConfiguration)
    } catch {
      Log.warning(
        "SwiftData recovery store failed (\(error)); using in-memory store (data won’t persist).",
        category: .app
      )
    }

    return makeInMemoryContainer(schema: schema)
  }
}

private let container: ModelContainer = {
  SwiftDataStoreBootstrap.makeModelContainer()
}()

enum SharedModelContainer {
  static var shared: ModelContainer?
}

@main
struct TymeBoxedApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  @Environment(\.scenePhase) private var scenePhase

  @StateObject private var requestAuthorizer = RequestAuthorizer()
  @StateObject private var donationManager = TipManager()
  @StateObject private var navigationManager = NavigationManager()
  @StateObject private var nfcWriter = NFCWriter()
  @StateObject private var ratingManager = RatingManager()

  // Singletons for shared functionality
  @StateObject private var startegyManager = StrategyManager.shared
  @StateObject private var liveActivityManager = LiveActivityManager.shared
  @StateObject private var themeManager = ThemeManager.shared

  @StateObject private var profileSyncManager = ProfileSyncManager.shared
  @StateObject private var syncCoordinator = SyncCoordinator.shared
  @StateObject private var cloudKitSyncStatus = CloudKitSyncStatus.shared

  @State private var showSyncUpgradeAlert = false

  init() {
    SharedModelContainer.shared = container
    TimersUtil.registerBackgroundTasks()

    let asyncDependency: @Sendable () async -> (ModelContainer) = {
      @MainActor in
      return container
    }
    AppDependencyManager.shared.add(
      key: "ModelContainer",
      dependency: asyncDependency
    )
  }

  var body: some Scene {
    WindowGroup {
      HomeView()
        .onOpenURL { url in
          handleUniversalLink(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) {
          userActivity in
          guard let url = userActivity.webpageURL else {
            return
          }
          handleUniversalLink(url)

        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            Task {
              await cloudKitSyncStatus.refresh()
              if profileSyncManager.isEnabled {
                await profileSyncManager.performFullSync()
                profileSyncManager.startSyncTimer()
              }
            }
          } else if newPhase == .inactive {
            // Pull session state as soon as the user leaves the app (e.g. stops timer on iPhone)
            // instead of waiting only for delayed CloudKit pushes or the next full sync.
            if profileSyncManager.isEnabled {
              Task {
                await profileSyncManager.refreshRemoteSessionStateFromCloud()
              }
            }
          } else if newPhase == .background {
            profileSyncManager.stopSyncTimer()
          }
        }
        .onReceive(profileSyncManager.$shouldShowSyncUpgradeNotice) { shouldShow in
          if shouldShow {
            showSyncUpgradeAlert = true
            profileSyncManager.shouldShowSyncUpgradeNotice = false
          }
        }
        .alert(
          "Multi-Device Sync Upgraded",
          isPresented: $showSyncUpgradeAlert
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(
            "Session sync uses an updated format. Update Tyme Boxed on all your devices for reliable cross-device sessions."
          )
        }
        .environmentObject(requestAuthorizer)
        .environmentObject(donationManager)
        .environmentObject(startegyManager)
        .environmentObject(navigationManager)
        .environmentObject(nfcWriter)
        .environmentObject(ratingManager)
        .environmentObject(liveActivityManager)
        .environmentObject(themeManager)
        .environmentObject(profileSyncManager)
        .environmentObject(cloudKitSyncStatus)
        .onAppear {
          syncCoordinator.setModelContext(container.mainContext)
          if profileSyncManager.isEnabled {
            Task {
              await profileSyncManager.setupSync()
            }
            profileSyncManager.startSyncTimer()
          }
          Task {
            await cloudKitSyncStatus.refresh()
          }
        }
    }
    .modelContainer(container)
  }

  private func handleUniversalLink(_ url: URL) {
    navigationManager.handleLink(url)
  }
}
