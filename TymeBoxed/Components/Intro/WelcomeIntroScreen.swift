import SwiftUI

struct WelcomeIntroScreen: View {
  @Environment(\.openURL) private var openURL
  @State private var showContent: Bool = false
  let onContinueWithEmail: () -> Void

  var body: some View {
    ZStack {
      // Background image (bundled for instant load)
      Image("WelcomeIntroBackground")
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea(.all)

      // Gradient overlay so content is readable
      VStack {
        Spacer()
        LinearGradient(
          colors: [Color.clear, Color.black.opacity(0.75)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 420)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(.all)

      VStack(spacing: 0) {
        Spacer()

        // Title section
        VStack(alignment: .leading, spacing: 12) {
          Text("Reclaim your time")
            .font(.system(size: 35))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -20)

          Text("Reclaim your mind")
            .font(.system(size: 35))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)

        // Buttons
        VStack(spacing: 16) {
          // Continue with email button
          Button(action: onContinueWithEmail) {
            Text("Continue")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.black)
              .frame(maxWidth: 350)
              .frame(height: 56)
              .background(
                RoundedRectangle(cornerRadius: 28)
                  .fill(Color.white)
              )
          }
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)

          // Secondary CTA — opens marketing site (same host as Terms / Privacy)
          Button {
            if let url = URL(string: "https://www.tymeboxed.app/") {
              openURL(url)
            }
          } label: {
            Text("I don't have a TymeBoxed")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: 350)
              .frame(height: 56)
              .background(
                RoundedRectangle(cornerRadius: 28)
                  .fill(Color.clear)
                  .overlay(
                    RoundedRectangle(cornerRadius: 28)
                      .stroke(Color.white.opacity(0.6), lineWidth: 1)
                  )
              )
          }
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 70)

        // Legal disclaimer
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            Text("By continuing, you agree to our")
              .font(.system(size: 12))
              .foregroundColor(Color.white.opacity(0.9))

            Link("Terms", destination: URL(string: "https://www.tymeboxed.app/terms")!)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color(red: 1, green: 0.85, blue: 0.6))
              .underline()

            Text("and")
              .font(.system(size: 12))
              .foregroundColor(Color.white.opacity(0.7))

            Link("Privacy Policy", destination: URL(string: "https://www.tymeboxed.app/privacy")!)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color(red: 1, green: 0.85, blue: 0.6))
              .underline()
          }
        }
        .padding(.bottom, 40)
        .opacity(showContent ? 1 : 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
        showContent = true
      }
    }
  }
}

#Preview {
  WelcomeIntroScreen(
    onContinueWithEmail: { print("Continue with email") }
  )
}
