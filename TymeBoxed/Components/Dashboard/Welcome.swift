import SwiftUI

struct DashboardHeroCard: View {
  @EnvironmentObject var themeManager: ThemeManager
  let topLabel: String
  let iconSystemName: String
  let headline: String
  var footnote: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(topLabel)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)

        Spacer()

        Image(systemName: iconSystemName)
          .font(.body)
          .foregroundColor(.white)
          .padding(8)
          .background(
            Circle()
              .fill(themeManager.themeColor.opacity(0.8))
          )
      }

      Spacer()
        .frame(height: 10)

      Text(headline)
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      if let footnote, !footnote.isEmpty {
        Text(footnote)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(3)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, minHeight: 150)
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color(UIColor.systemBackground))
        .overlay(
          GeometryReader { geometry in
            ZStack {
              Circle()
                .fill(themeManager.themeColor.opacity(0.5))
                .frame(width: geometry.size.width * 0.5)
                .position(
                  x: geometry.size.width * 0.9,
                  y: geometry.size.height / 2
                )
                .blur(radius: 15)
            }
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 24)
            .fill(.ultraThinMaterial.opacity(0.7))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    )
  }
}

struct IphoneCompanionSyncCard: View {
  var body: some View {
    DashboardHeroCard(
      topLabel: "Sync with iPhone",
      iconSystemName: "iphone",
      headline:
        "This is a companion app for your iPhone. Please create a profile on iPhone to sync.",
      footnote: nil
    )
  }
}

#Preview {
  ZStack {
    Color.gray.opacity(0.1).ignoresSafeArea()

    IphoneCompanionSyncCard()
      .padding(.horizontal)
      .environmentObject(ThemeManager.shared)
  }
}
