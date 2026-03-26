import Foundation
import SwiftUI

class AuthenticationManager: ObservableObject {
  static let shared = AuthenticationManager()

  @Published var isAuthenticated = false
  @Published var email: String = ""
  @Published var phone: String = ""
  @Published var loginType: LoginType = .email
  @Published var isLoading = false
  @Published var errorMessage: String? = nil
  @Published var otpSent = false
  @Published var otpCode: String = ""

  private let userDefaults = UserDefaults.standard
  private let emailKey = "userEmail"
  private let phoneKey = "userPhone"
  private let loginTypeKey = "loginType"
  private let isAuthenticatedKey = "isAuthenticated"
  private let authTokenKey = "authToken"
  private let cachedNFCTagIdsKey = "cachedNFCTagIds"

  enum LoginType: String, Codable {
    case email
    case phone
    case google
    case apple
  }

  private init() {
    // Check if user is already authenticated
    isAuthenticated = userDefaults.bool(forKey: isAuthenticatedKey)
    email = userDefaults.string(forKey: emailKey) ?? ""
    phone = userDefaults.string(forKey: phoneKey) ?? ""
    if let savedType = userDefaults.string(forKey: loginTypeKey),
       let type = LoginType(rawValue: savedType) {
      loginType = type
    }
  }

  func sendOTP(email: String? = nil, phone: String? = nil) async {
    await MainActor.run {
      self.isLoading = true
      self.errorMessage = nil
      if let email = email {
        self.email = email
        self.loginType = .email
      }
      if let phone = phone {
        self.phone = phone
        self.loginType = .phone
      }
    }

    do {
      let response = try await APIService.sendOTP(email: email, phone: phone)
      
      await MainActor.run {
        self.isLoading = false
        if response.success {
          self.otpSent = true
        } else {
          self.errorMessage = response.message ?? "Failed to send OTP. Please try again."
          self.otpSent = false
        }
      }
    } catch {
      await MainActor.run {
        self.isLoading = false
        self.errorMessage = error.localizedDescription
        self.otpSent = false
        
        #if DEBUG
        print("API Error: \(error.localizedDescription)")
        print("Using mock OTP for development. Configure your backend API URL in APIService.swift")
        self.otpSent = true
        self.otpCode = generateMockOTP()
        print("Mock OTP: \(self.otpCode)")
        #endif
      }
    }
  }

  func verifyOTP(_ otp: String) async -> Bool {
    await MainActor.run {
      self.isLoading = true
      self.errorMessage = nil
    }

    do {
      let email = loginType == .email ? self.email : nil
      let phone = loginType == .phone ? self.phone : nil
      let response = try await APIService.verifyOTP(email: email, phone: phone, otp: otp)
      
      await MainActor.run {
        self.isLoading = false
        if response.success {
          self.isAuthenticated = true
          self.userDefaults.set(true, forKey: self.isAuthenticatedKey)
          self.userDefaults.set(self.email, forKey: self.emailKey)
          self.userDefaults.set(self.phone, forKey: self.phoneKey)
          self.userDefaults.set(self.loginType.rawValue, forKey: self.loginTypeKey)
          self.otpSent = false
          self.otpCode = ""
          
          if let token = response.token {
            self.userDefaults.set(token, forKey: self.authTokenKey)
          }
        } else {
          self.errorMessage = response.message ?? "Invalid OTP. Please try again."
        }
      }
      
      return response.success
    } catch {
      return await MainActor.run {
        self.isLoading = false

        #if DEBUG
        if otp == self.otpCode {
          self.isAuthenticated = true
          self.userDefaults.set(true, forKey: self.isAuthenticatedKey)
          self.userDefaults.set(self.email, forKey: self.emailKey)
          self.userDefaults.set(self.phone, forKey: self.phoneKey)
          self.userDefaults.set(self.loginType.rawValue, forKey: self.loginTypeKey)
          self.otpSent = false
          self.otpCode = ""
          print("Mock OTP verified successfully")
          return true
        } else {
          self.errorMessage = "Invalid OTP. Please try again."
          return false
        }
        #else
        self.errorMessage = error.localizedDescription
        return false
        #endif
      }
    }
  }

  /// Permanently deletes the account on the server (if API supports it) and clears all local auth data.
  func deleteAccount() async {
    if let token = authToken {
      do {
        _ = try await APIService.deleteAccount(token: token)
      } catch {
        #if DEBUG
        print("Delete account API error (proceeding with local cleanup): \(error.localizedDescription)")
        #endif
      }
    }
    logout()
  }

  func logout() {
    isAuthenticated = false
    email = ""
    phone = ""
    otpSent = false
    otpCode = ""
    loginType = .email
    userDefaults.removeObject(forKey: isAuthenticatedKey)
    userDefaults.removeObject(forKey: emailKey)
    userDefaults.removeObject(forKey: phoneKey)
    userDefaults.removeObject(forKey: loginTypeKey)
    userDefaults.removeObject(forKey: authTokenKey)
    userDefaults.removeObject(forKey: cachedNFCTagIdsKey)
  }

  var authToken: String? {
    userDefaults.string(forKey: authTokenKey)
  }

  /// Cached NFC tag IDs (per user on this device). First time: verify from DB and save here. Same user again: verify from cache only (no DB call). New user: verify from DB then save to cache.
  private var cachedNFCTagIds: Set<String> {
    get {
      let list = userDefaults.stringArray(forKey: cachedNFCTagIdsKey) ?? []
      return Set(list)
    }
    set {
      userDefaults.set(Array(newValue), forKey: cachedNFCTagIdsKey)
    }
  }

  /// NFC verify: check tag in DB (no login required). Cache valid tagIds to reduce API calls.
  func isNFCTagValidForUnlock(tagId: String) async -> Bool {
    if cachedNFCTagIds.contains(tagId) {
      print("[NFC Cache] Tag '\(tagId)' found in cache - using cached value")
      return true
    }
    print("[NFC Cache] Tag '\(tagId)' not in cache - verifying from DB...")
    do {
      let response = try await APIService.verifyNFCTag(tagId: tagId, token: authToken)
      if response.valid {
        var cache = cachedNFCTagIds
        cache.insert(tagId)
        cachedNFCTagIds = cache
        print("[NFC Cache] Tag '\(tagId)' verified from DB and saved to cache. Cache now contains \(cache.count) tag(s)")
        return true
      } else {
        print("[NFC Cache] Tag '\(tagId)' verified from DB but is invalid - not cached")
      }
      return false
    } catch {
      print("[NFC Cache] Error verifying tag '\(tagId)' from DB: \(error.localizedDescription)")
      return false
    }
  }

  var identifier: String {
    switch loginType {
    case .email: return email
    case .phone: return phone
    case .google: return email
    case .apple: return email
    }
  }

  /// Sign in with Google ID token from Google Sign-In SDK. Saves auth state on success.
  func signInWithGoogle(idToken: String) async -> Bool {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }
    do {
      let response = try await APIService.signInWithGoogle(idToken: idToken)
      await MainActor.run {
        isLoading = false
        if response.success {
          isAuthenticated = true
          loginType = .google
          email = response.user?.email ?? ""
          phone = response.user?.phone ?? ""
          userDefaults.set(true, forKey: isAuthenticatedKey)
          userDefaults.set(email, forKey: emailKey)
          userDefaults.set(phone, forKey: phoneKey)
          userDefaults.set(loginType.rawValue, forKey: loginTypeKey)
          if let token = response.token {
            userDefaults.set(token, forKey: authTokenKey)
          }
        } else {
          errorMessage = response.message ?? "Failed to sign in with Google."
        }
      }
      return response.success
    } catch {
      await MainActor.run {
        isLoading = false
        errorMessage = error.localizedDescription
      }
      return false
    }
  }

  /// Sign in with Apple. Saves auth state on success.
  func signInWithApple(
    identityToken: String,
    authorizationCode: String? = nil,
    fullName: PersonNameComponents? = nil,
    email: String? = nil
  ) async -> Bool {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }
    do {
      let response = try await APIService.signInWithApple(
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        fullName: fullName,
        email: email
      )
      await MainActor.run {
        isLoading = false
        if response.success {
          isAuthenticated = true
          loginType = .apple
          self.email = response.user?.email ?? email ?? ""
          phone = response.user?.phone ?? ""
          userDefaults.set(true, forKey: isAuthenticatedKey)
          userDefaults.set(self.email, forKey: emailKey)
          userDefaults.set(phone, forKey: phoneKey)
          userDefaults.set(loginType.rawValue, forKey: loginTypeKey)
          if let token = response.token {
            userDefaults.set(token, forKey: authTokenKey)
          }
        } else {
          errorMessage = response.message ?? "Failed to sign in with Apple."
        }
      }
      return response.success
    } catch {
      await MainActor.run {
        isLoading = false
        errorMessage = error.localizedDescription
      }
      return false
    }
  }

  /// Debug helper: Get cached NFC tag IDs count
  func getCachedNFCTagCount() -> Int {
    return cachedNFCTagIds.count
  }

  /// Debug helper: Check if a specific tag ID is cached
  func isNFCTagCached(tagId: String) -> Bool {
    return cachedNFCTagIds.contains(tagId)
  }

  /// Debug helper: Get all cached NFC tag IDs
  func getCachedNFCTagIds() -> [String] {
    return Array(cachedNFCTagIds).sorted()
  }

  private func generateMockOTP() -> String {
    // Generate a 6-digit OTP
    return String(format: "%06d", Int.random(in: 100000...999999))
  }
}
