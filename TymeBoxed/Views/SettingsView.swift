import FamilyControls
import SwiftData
import SwiftUI
import UIKit

let AMZN_STORE_LINK = "https://amzn.to/4fbMuTM"

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @EnvironmentObject var themeManager: ThemeManager
  @EnvironmentObject var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject var strategyManager: StrategyManager
  @EnvironmentObject private var profileSyncManager: ProfileSyncManager
  @EnvironmentObject private var cloudKitSyncStatus: CloudKitSyncStatus

  var showsDismissButton: Bool = true

  @State private var showResetBlockingStateAlert = false
  @State private var showResetSyncAlert = false
  @State private var showDeleteAccountAlert = false
  @State private var isDeletingAccount = false
  @State private var syncErrorMessage: String?
  @AppStorage("showIntroScreen") private var showIntroScreen = true

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "1.0"
  }

  private var syncStatusColor: Color {
    switch profileSyncManager.syncStatus {
    case .disabled:
      return .gray
    case .idle:
      return .green
    case .syncing:
      return .orange
    case .error:
      return .red
    }
  }

  private var iCloudStatusColor: Color {
    cloudKitSyncStatus.isSignedIn ? .green : .red
  }

  private var iCloudStatusText: String {
    cloudKitSyncStatus.isSignedIn ? "Signed in to iCloud" : "Not signed in to iCloud"
  }

  @ViewBuilder
  private var deviceSyncSection: some View {
    Section {
      HStack {
        Image(
          systemName: cloudKitSyncStatus.isSignedIn ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill"
        )
        .foregroundStyle(iCloudStatusColor)
        .font(.title3)

        VStack(alignment: .leading, spacing: 2) {
          Text(iCloudStatusText)
            .font(.subheadline)
            .foregroundStyle(cloudKitSyncStatus.isSignedIn ? Color.primary : Color.red)
          if !cloudKitSyncStatus.isSignedIn {
            Text("Sign in to iCloud to use sync")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if !cloudKitSyncStatus.isSignedIn {
          Spacer()
          Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
          .font(.caption)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(themeManager.themeColor)
        }
      }
      .padding(.vertical, 2)

      HStack {
        Text("Sync Status")
          .foregroundStyle(.primary)
        Spacer()
        HStack(spacing: 8) {
          if profileSyncManager.isSyncing {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Circle()
              .fill(syncStatusColor)
              .frame(width: 8, height: 8)
          }
          Text(profileSyncManager.syncStatus.displayText)
            .foregroundStyle(.secondary)
            .font(.subheadline)
        }
      }

      if let lastSync = profileSyncManager.lastSyncDate {
        HStack {
          Text("Last Synced")
            .foregroundStyle(.primary)
          Spacer()
          Text(lastSync, style: .relative)
            .foregroundStyle(.secondary)
            .font(.subheadline)
        }
      }

      Button {
        Task {
          await profileSyncManager.performFullSync()
        }
      } label: {
        HStack {
          Image(systemName: "arrow.clockwise")
            .foregroundColor(themeManager.themeColor)
          Text("Sync Now")
            .foregroundColor(.primary)
          Spacer()
          if profileSyncManager.isSyncing {
            ProgressView()
              .scaleEffect(0.8)
          }
        }
      }
      .disabled(profileSyncManager.isSyncing)
    } header: {
      Text("Device Sync")
    } footer: {
      Text(
        "Profiles sync to devices signed in with the same iCloud account. App selections are configured per device."
      )
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("About") {
          HStack {
            Text("Version")
              .foregroundStyle(.primary)
            Spacer()
            Text("v\(appVersion)")
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Screen Time Access")
              .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 8) {
              Circle()
                .fill(requestAuthorizer.getAuthorizationStatus() == .approved ? .green : .red)
                .frame(width: 8, height: 8)
              Text(requestAuthorizer.getAuthorizationStatus() == .approved ? "Authorized" : "Not Authorized")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
          }

          HStack {
            Text("Made in")
              .foregroundStyle(.primary)
            Spacer()
            Text("Hyderabad India 🇮🇳")
              .foregroundStyle(.secondary)
          }
        }

        deviceSyncSection

        // Section("Help") {
        //   Link(destination: URL(string: "https://www.timeboxed.app/blocking-native-apps.html")!) {
        //     HStack {
        //       Text("Blocking Native Apps")
        //         .foregroundColor(.primary)
        //       Spacer()
        //       Image(systemName: "arrow.up.right.square")
        //         .foregroundColor(.secondary)
        //     }
        //   }
        // }

        if !strategyManager.isBlocking {
          Section("Troubleshooting") {
            Button {
              showResetBlockingStateAlert = true
            } label: {
              Text("Reset Blocking State")
                .foregroundColor(themeManager.themeColor)
            }

            if profileSyncManager.isEnabled {
              Button {
                showResetSyncAlert = true
              } label: {
                Text("Reset Syncing")
                  .foregroundColor(themeManager.themeColor)
              }
            }
          }
        }

        Section {
          Button(role: .destructive) {
            showDeleteAccountAlert = true
          } label: {
            HStack {
              Image(systemName: "trash")
              Text("Delete Account")
            }
          }
          .disabled(isDeletingAccount)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        if showsDismissButton {
          ToolbarItem(placement: .topBarLeading) {
            Button(action: { dismiss() }) {
              Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
          }
        }
      }
      .contentMargins(
        .bottom,
        showsDismissButton ? 0 : MainTabBar.formBottomScrollInset,
        for: .scrollContent
      )
      .alert("Reset Blocking State", isPresented: $showResetBlockingStateAlert) {
        Button("Cancel", role: .cancel) { }
        Button("Reset", role: .destructive) {
          strategyManager.resetBlockingState(context: context)
        }
      } message: {
        Text("This will clear all app restrictions and remove any ghost schedules. Only use this if you're locked out and no profile is active.")
      }
      .alert("Reset Syncing", isPresented: $showResetSyncAlert) {
        Button("Cancel", role: .cancel) {}
        Button("Keep App Selections") {
          Task {
            do {
              try await profileSyncManager.resetSync(clearRemoteAppSelections: false)
            } catch {
              Log.error(
                "Failed to reset sync (keep selections): \(error.localizedDescription)",
                category: .sync)
              syncErrorMessage = "Sync reset failed: \(error.localizedDescription)"
            }
          }
        }
        Button("Clear App Selections", role: .destructive) {
          Task {
            do {
              try await profileSyncManager.resetSync(clearRemoteAppSelections: true)
            } catch {
              Log.error(
                "Failed to reset sync (clear selections): \(error.localizedDescription)",
                category: .sync)
              syncErrorMessage = "Sync reset failed: \(error.localizedDescription)"
            }
          }
        }
      } message: {
        Text(
          "This will re-sync from this device. Choose how other devices should respond:\n\n• Keep app selections: Other devices keep their blocked apps\n• Clear app selections: Other devices must re-select apps"
        )
      }
      .alert(
        "Sync Error",
        isPresented: .init(
          get: { syncErrorMessage != nil },
          set: { if !$0 { syncErrorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        if let message = syncErrorMessage {
          Text(message)
        }
      }
      .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
          performDeleteAccount()
        }
      } message: {
        Text("This will permanently delete all your modes, schedules, and activity. This action cannot be undone.")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func performDeleteAccount() {
    isDeletingAccount = true

    Task { @MainActor in
      strategyManager.forceStopBlockingForAccountDeletion(context: context)
      AppBlockerUtil().deactivateRestrictions()

      try? await Task.sleep(nanoseconds: 300_000_000)
      let profiles = (try? BlockedProfiles.fetchProfiles(in: context)) ?? []
      for profile in profiles {
        try? BlockedProfiles.deleteProfile(profile, in: context)
      }
      try? context.save()

      ActiveSessionShieldTimerActivity.removeAllMonitors()
      SharedData.clearAllForAccountDeletion()

      await AuthenticationManager.shared.deleteAccount()

      showIntroScreen = true
      isDeletingAccount = false
      dismiss()
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(ThemeManager.shared)
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager.shared)
    .environmentObject(ProfileSyncManager.shared)
    .environmentObject(CloudKitSyncStatus.shared)
}
