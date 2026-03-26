import SwiftUI
import UIKit

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
}

struct MainTabBar: View {
  @EnvironmentObject var themeManager: ThemeManager
  @Binding var selection: MainTab

  private let iconPointSize: CGFloat = 22

  static let formBottomScrollInset: CGFloat = 72

  var body: some View {
    HStack(spacing: 0) {
      ForEach(MainTab.allCases) { tab in
        tabButton(tab)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 8)
    .padding(.top, 10)
    .padding(.bottom, 6)
    .background {
      Rectangle()
        .fill(Color(uiColor: .systemGray5))
        .ignoresSafeArea(edges: .bottom)
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color(uiColor: .separator))
        .frame(height: 1)
    }
  }

  private func tabButton(_ tab: MainTab) -> some View {
    let isSelected = selection == tab
    return Button {
      selection = tab
    } label: {
      Image(systemName: tab.systemImage)
        .font(.system(size: iconPointSize, weight: .regular))
        .foregroundStyle(
          isSelected
            ? themeManager.themeColor
            : Color.secondary
        )
        .padding(.vertical, 10)
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
