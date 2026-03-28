import FamilyControls
import SwiftData
import SwiftUI

/// Prompt when a synced profile needs local app selection.
struct AppSelectionPrompt: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @EnvironmentObject var themeManager: ThemeManager

  let profile: BlockedProfiles

  @State private var showAppPicker = false
  @State private var localSelection: FamilyActivitySelection
  @State private var saveErrorMessage: String?

  init(profile: BlockedProfiles) {
    self.profile = profile
    self._localSelection = State(initialValue: profile.selectedActivity)
  }

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 12) {
        Image(systemName: "apps.iphone")
          .font(.system(size: 48))
          .foregroundStyle(themeManager.themeColor)

        Text("Select Apps for This Device")
          .font(.headline)

        Text(
          "This profile was synced from another device. Select which apps to block on this device."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Profile")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text(profile.name)
            .font(.caption)
            .bold()
        }

        if hasAppsSelected {
          HStack {
            Text("Apps Selected")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Text(selectionSummary)
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(12)
      .padding(.horizontal)

      VStack(spacing: 12) {
        Button {
          showAppPicker = true
        } label: {
          HStack {
            Image(systemName: "plus.app")
            Text(hasAppsSelected ? "Change App Selection" : "Select Apps to Block")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(themeManager.themeColor)
          .foregroundColor(.white)
          .cornerRadius(12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if hasAppsSelected {
          Button {
            saveSelection()
          } label: {
            HStack {
              Image(systemName: "checkmark.circle")
              Text("Save Selection")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal)
    }
    .padding(.vertical)
    .alert(
      "Couldn’t Save",
      isPresented: .init(
        get: { saveErrorMessage != nil },
        set: { if !$0 { saveErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      if let saveErrorMessage {
        Text(saveErrorMessage)
      }
    }
    .sheet(isPresented: $showAppPicker) {
      AppPicker(
        selection: $localSelection,
        isPresented: $showAppPicker,
        allowMode: profile.enableAllowMode
      )
    }
  }

  private var hasAppsSelected: Bool {
    !localSelection.applicationTokens.isEmpty
      || !localSelection.categoryTokens.isEmpty
      || !localSelection.webDomainTokens.isEmpty
  }

  private var selectionSummary: String {
    let appCount = localSelection.applicationTokens.count
    let catCount = localSelection.categoryTokens.count
    let webCount = localSelection.webDomainTokens.count

    var parts: [String] = []
    if appCount > 0 { parts.append("\(appCount) apps") }
    if catCount > 0 { parts.append("\(catCount) categories") }
    if webCount > 0 { parts.append("\(webCount) websites") }

    return parts.isEmpty ? "None" : parts.joined(separator: ", ")
  }

  private func saveSelection() {
    do {
      guard let liveProfile = try BlockedProfiles.findProfile(byID: profile.id, in: context) else {
        saveErrorMessage = "This profile is no longer available. Try closing and reopening the app."
        return
      }

      _ = try BlockedProfiles.updateProfile(
        liveProfile,
        in: context,
        selection: localSelection,
        reminderTime: liveProfile.reminderTimeInSeconds,
        customReminderMessage: liveProfile.customReminderMessage,
        physicalUnblockNFCTagId: liveProfile.physicalUnblockNFCTagId,
        physicalUnblockQRCodeId: liveProfile.physicalUnblockQRCodeId,
        needsAppSelection: false
      )

      SyncCoordinator.shared.pushProfile(liveProfile)
      Log.info("Saved app selection for profile '\(liveProfile.name)'", category: .ui)
      dismiss()
    } catch {
      Log.error("Failed to save app selection: \(error)", category: .ui)
      saveErrorMessage = error.localizedDescription
    }
  }
}

struct AppSelectionRequiredBanner: View {
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)

      Text("Select apps on this device")
        .font(.caption)
        .foregroundStyle(.primary)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.orange.opacity(0.15))
    .cornerRadius(8)
  }
}

struct AppSelectionPromptModifier: ViewModifier {
  @Binding var isPresented: Bool
  let profile: BlockedProfiles

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $isPresented) {
        NavigationStack {
          AppSelectionPrompt(profile: profile)
            .navigationTitle("App Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                  isPresented = false
                }
              }
            }
        }
      }
  }
}

extension View {
  func appSelectionPrompt(isPresented: Binding<Bool>, profile: BlockedProfiles) -> some View {
    modifier(AppSelectionPromptModifier(isPresented: isPresented, profile: profile))
  }
}
