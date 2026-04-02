import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
  case profile
  case activity
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .activity: return "Activity"
    case .profile: return "Profile"
    case .settings: return "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .activity: return "trophy.fill"
    case .profile: return "person.fill"
    case .settings: return "gearshape.fill"
    }
  }

  var accessibilityLabel: String { title }

  /// Matches the reference layout: only the first tab shows a small caps label under the icon.
  var showsTabBarSubtitle: Bool {
    switch self {
    case .profile: return true
    case .activity, .settings: return false
    }
  }
}

struct MainTabBar: View {
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject var themeManager: ThemeManager
  @Binding var selection: MainTab

  private let iconPointSize: CGFloat = 22
  private let barCornerRadius: CGFloat = 32

  /// Scroll clearance for `Form` / lists behind the floating bar (profile tab uses safe area only).
  static let formBottomScrollInset: CGFloat = 92

  private var floatingBarFill: Color {
    colorScheme == .dark
      ? Color(white: 0.19)
      : Color(red: 0.96, green: 0.96, blue: 0.95)
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(MainTab.allCases) { tab in
        tabButton(tab)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 10)
    .padding(.top, 12)
    .padding(.bottom, 12)
    .background {
      RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
        .fill(floatingBarFill)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 16, y: 6)
    }
  }

  private var idleTabTint: Color {
    colorScheme == .dark
      ? Color(white: 0.55)
      : Color(red: 0.42, green: 0.40, blue: 0.38)
  }

  private func tabButton(_ tab: MainTab) -> some View {
    let isSelected = selection == tab
    return Button {
      selection = tab
    } label: {
      Group {
        if tab.showsTabBarSubtitle {
          VStack(spacing: 5) {
            Image(systemName: tab.systemImage)
              .font(.system(size: iconPointSize, weight: .regular))
            Text(tab.title.uppercased())
              .font(.system(size: 9, weight: .semibold))
              .tracking(0.6)
          }
        } else {
          Image(systemName: tab.systemImage)
            .font(.system(size: iconPointSize, weight: .regular))
        }
      }
      .foregroundStyle(isSelected ? themeManager.themeColor : idleTabTint)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(tab.accessibilityLabel))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview {
  struct PreviewWrapper: View {
    @State private var tab: MainTab = .profile

    var body: some View {
      ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        MainTabBar(selection: $tab)
          .environmentObject(ThemeManager.shared)
      }
    }
  }

  return PreviewWrapper()
}
