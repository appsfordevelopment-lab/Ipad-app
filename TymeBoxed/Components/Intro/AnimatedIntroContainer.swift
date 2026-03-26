import SwiftUI

struct AnimatedIntroContainer: View {
  @State private var currentStep: Int = 0
  @StateObject private var authManager = AuthenticationManager.shared
  let onRequestAuthorization: () -> Void

  private let totalSteps = 3

  var body: some View {
    VStack(spacing: 0) {
      // Content area
      Group {
        switch currentStep {
        case 0:
          WelcomeIntroScreen(
            onContinueWithEmail: {
              handleNext()
            }
          )
        case 1:
          LoginScreen(
            onLoginSuccess: {
              handleLoginSuccess()
            },
            onBack: {
              handleBack()
            }
          )
        case 2:
          PermissionsScreen(
            onRequestAuthorization: {
              onRequestAuthorization()
            },
            onBack: {
              handleBack()
            }
          )
        default:
          WelcomeIntroScreen(
            onContinueWithEmail: {
              handleNext()
            }
          )
        }
      }
      .transition(
        .asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .leading).combined(with: .opacity)
        )
      )
      .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    .onAppear {
      // If already authenticated, go to permissions screen (don't skip it)
      // User must tap "Allow access" to proceed to Home
      if authManager.isAuthenticated {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
          currentStep = 2
        }
      }
    }
  }

  private func handleNext() {
    if currentStep < totalSteps - 1 {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        currentStep += 1
      }
    } else {
      // Last step - request authorization
      onRequestAuthorization()
    }
  }

  private func handleBack() {
    if currentStep > 0 {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        currentStep -= 1
      }
    }
  }

  private func handleLoginSuccess() {
    // After successful OTP login, navigate to permissions screen
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      currentStep = 2
    }
  }

  private func getNextButtonTitle() -> String {
    switch currentStep {
    case totalSteps - 1:
      return "Continue"
    default:
      return "Continue"
    }
  }
}

#Preview {
  AnimatedIntroContainer(
    onRequestAuthorization: {
      print("Request authorization")
    }
  )
}
