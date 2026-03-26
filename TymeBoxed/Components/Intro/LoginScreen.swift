import AuthenticationServices
import GoogleSignIn
import SwiftUI

struct LoginScreen: View {
  // Phone OTP (commented off – using email instead)
  // @State private var phone: String = ""
  // @State private var selectedCountryIndex: Int = 0
  @State private var email: String = ""
  @State private var showingOTPScreen = false
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var errorMessage: String? = nil

  // Phone OTP – country codes (commented off, using email instead)
  // private let countryCodes: [(code: String, name: String, flag: String)] = [...]
  // private var selectedCountry: (code: String, name: String, flag: String) { ... }
  // private var selectedCountryCode: String { ... }

  let onLoginSuccess: () -> Void
  let onBack: (() -> Void)?

  init(onLoginSuccess: @escaping () -> Void, onBack: (() -> Void)? = nil) {
    self.onLoginSuccess = onLoginSuccess
    self.onBack = onBack
  }

  var body: some View {
    ZStack {
      Color(uiColor: .systemBackground)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Back button
        HStack {
          if let onBack = onBack {
            Button(action: onBack) {
              Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(
                  Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
            .padding(.leading, 20)
            .padding(.top, 8)
          }
          Spacer()
        }
        .padding(.top, 8)

        // Title - center aligned
        Text("Enter your email to get started")
          .font(.system(size: 30))
          .foregroundColor(.primary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
          .padding(.top, 40)
          .padding(.bottom, 32)

        // Email input field - center aligned
        TextField("Email address", text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .autocapitalization(.none)
          .autocorrectionDisabled()
          .padding(16)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color(uiColor: .tertiarySystemFill))
          )
          .padding(.horizontal, 20)
          .padding(.bottom, 8)

        // Hint text - center aligned
        Text("We'll send you a verification code to confirm it's you")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
          .padding(.bottom, 8)

        // Error message
        if let errorMessage = errorMessage {
          Text(errorMessage)
            .font(.system(size: 14))
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }

        Spacer()

        // Get verification code button - center aligned
        Button(action: {
          Task {
            await sendOTP()
          }
        }) {
          HStack {
            if authManager.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(uiColor: .systemBackground)))
            }
            Text("Get verification code")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(
                isValidEmail(email) && !authManager.isLoading
                  ? Color(uiColor: .systemBackground) : Color(uiColor: .tertiaryLabel)
              )
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(
                isValidEmail(email) && !authManager.isLoading
                  ? Color.primary : Color(uiColor: .tertiarySystemFill)
              )
          )
        }
        .disabled(!isValidEmail(email) || authManager.isLoading)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)

        // OR divider
        HStack(spacing: 12) {
          Rectangle()
            .fill(Color(uiColor: .tertiaryLabel).opacity(0.5))
            .frame(height: 1)
          Text("OR")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
          Rectangle()
            .fill(Color(uiColor: .tertiaryLabel).opacity(0.5))
            .frame(height: 1)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)

        // Google and Apple login buttons
        HStack(spacing: 24) {
          Button(action: signInWithGoogle) {
            GoogleGLogo(size: 54)
              .frame(width: 56, height: 56)
              .background(
                Circle()
                  .fill(Color.white)
                  .overlay(
                    Circle()
                      .stroke(Color(uiColor: .separator), lineWidth: 1)
                  )
              )
          }
          .buttonStyle(.plain)

          Button(action: signInWithApple) {
            Image(systemName: "apple.logo")
              .font(.system(size: 34, weight: .medium))
              .foregroundColor(.primary)
              .frame(width: 56, height: 56)
              .background(
                Circle()
                  .fill(Color(uiColor: .secondarySystemBackground))
              )
          }
          .buttonStyle(.plain)
        }
        .padding(.bottom, 40)
      }
    }
    .sheet(isPresented: $showingOTPScreen) {
      OTPScreen(
        identifier: email.trimmingCharacters(in: .whitespacesAndNewlines),
        loginType: .email,
        onVerificationSuccess: {
          showingOTPScreen = false
          onLoginSuccess()
        },
        onDismiss: {
          showingOTPScreen = false
        }
      )
    }
  }

  private func signInWithGoogle() {
    Task {
      await performGoogleSignIn()
    }
  }

  private func performGoogleSignIn() async {
    guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
          !clientID.contains("YOUR_") else {
      errorMessage = "Google Sign-In is not configured. Add your Google Client ID to Info.plist."
      return
    }
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else {
      errorMessage = "Could not present Google Sign-In."
      return
    }
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config
    do {
      let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
      guard let idToken = result.user.idToken?.tokenString else {
        errorMessage = "Could not get ID token from Google."
        return
      }
      let success = await authManager.signInWithGoogle(idToken: idToken)
      if success {
        onLoginSuccess()
      } else {
        errorMessage = authManager.errorMessage ?? "Failed to sign in with Google."
      }
    } catch {
      let nsError = error as NSError
      let isCanceled = nsError.code == -5
        || nsError.localizedDescription.lowercased().contains("cancel")
      if isCanceled { return }
      errorMessage = error.localizedDescription
    }
  }

  @State private var appleSignInHandler: AppleSignInHandler?

  private func signInWithApple() {
    let handler = AppleSignInHandler(
      onSuccess: { [self] identityToken, authCode, fullName, email in
        Task { @MainActor in
          let success = await authManager.signInWithApple(
            identityToken: identityToken,
            authorizationCode: authCode,
            fullName: fullName,
            email: email
          )
          if success {
            onLoginSuccess()
          } else {
            errorMessage = authManager.errorMessage ?? "Failed to sign in with Apple."
          }
          appleSignInHandler = nil
        }
      },
      onError: { [self] err in
        Task { @MainActor in
          let nsErr = err as NSError
          if nsErr.code == ASAuthorizationError.canceled.rawValue { return }
          errorMessage = err.localizedDescription
          appleSignInHandler = nil
        }
      }
    )
    appleSignInHandler = handler
    handler.performSignIn()
  }

  private func sendOTP() async {
    errorMessage = nil
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

    await authManager.sendOTP(email: trimmedEmail)

    if authManager.otpSent {
      showingOTPScreen = true
    } else {
      errorMessage = authManager.errorMessage ?? "Failed to send OTP. Please try again."
    }
  }

  /// Basic email format validation.
  private func isValidEmail(_ email: String) -> Bool {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    return trimmed.range(of: emailRegex, options: .regularExpression) != nil
  }

  // Phone OTP helpers (commented off)
  // private func nationalDigits(from phone: String) -> String { ... }
  // private func isValidPhone(_ phone: String) -> Bool { ... }
  // private func formatPhoneNumber(_ phone: String) -> String { ... }
}

private final class AppleSignInHandler: NSObject,
  ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding {
  private let onSuccess: (String, String?, PersonNameComponents?, String?) -> Void
  private let onError: (Error) -> Void

  init(
    onSuccess: @escaping (String, String?, PersonNameComponents?, String?) -> Void,
    onError: @escaping (Error) -> Void
  ) {
    self.onSuccess = onSuccess
    self.onError = onError
    super.init()
  }

  func performSignIn() {
    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let identityTokenData = credential.identityToken,
          let identityToken = String(data: identityTokenData, encoding: .utf8) else {
      onError(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential"]))
      return
    }
    let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    onSuccess(identityToken, authCode, credential.fullName, credential.email)
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    onError(error)
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow } ?? UIWindow()
  }
}

#Preview {
  LoginScreen(
    onLoginSuccess: {
      print("Login successful")
    },
    onBack: {
      print("Back tapped")
    }
  )
}
