import Foundation

struct APIService {
  //static let baseURL = "http://localhost:3000/api"
  //static let baseURL = "https://time-boxed.onrender.com/api"
  static let baseURL = "https://api.tymeboxed.app/api"
  struct ErrorResponse: Codable {
    let message: String?
  }

  enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, serverMessage: String?)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
      switch self {
      case .invalidURL:
        return "Invalid API URL"
      case .invalidResponse:
        return "Invalid response from server"
      case .httpError(let code, let serverMessage):
        return serverMessage ?? "Server error: \(code)"
      case .decodingError:
        return "Failed to decode response"
      case .networkError(let error):
        return error.localizedDescription
      }
    }
  }
  
  struct SendOTPRequest: Codable {
    let email: String?
    let phone: String?
    
    init(email: String? = nil, phone: String? = nil) {
      self.email = email
      self.phone = phone
    }
  }
  
  struct SendOTPResponse: Codable {
    let success: Bool
    let message: String?
    let expiresIn: Int? // OTP expiration time in seconds
  }
  
  struct VerifyOTPRequest: Codable {
    let email: String?
    let phone: String?
    let otp: String
    
    init(email: String? = nil, phone: String? = nil, otp: String) {
      self.email = email
      self.phone = phone
      self.otp = otp
    }
  }
  
  struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
    let user: AuthUser?
  }

  struct AuthUser: Codable {
    let id: String?
    let name: String?
    let phone: String?
    let email: String?
    let loginProviders: [String]?
  }

  struct GoogleAuthRequest: Codable {
    let idToken: String
  }

  struct GoogleAuthResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
    let user: AuthUser?
  }

  struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let name: String?
    let email: String?
  }

  struct AppleAuthResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
    let user: AuthUser?
  }

  static func signInWithGoogle(idToken: String) async throws -> GoogleAuthResponse {
    guard let url = URL(string: "\(baseURL)/auth/google") else { throw APIError.invalidURL }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(GoogleAuthRequest(idToken: idToken))
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
    guard (200...299).contains(httpResponse.statusCode) else {
      let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
      throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
    }
    return try JSONDecoder().decode(GoogleAuthResponse.self, from: data)
  }

  static func signInWithApple(
    identityToken: String,
    authorizationCode: String? = nil,
    fullName: PersonNameComponents? = nil,
    email: String? = nil
  ) async throws -> AppleAuthResponse {
    let name: String?
    if let comp = fullName {
      var parts: [String] = []
      if let given = comp.givenName { parts.append(given) }
      if let family = comp.familyName { parts.append(family) }
      name = parts.isEmpty ? nil : parts.joined(separator: " ")
    } else {
      name = nil
    }
    guard let url = URL(string: "\(baseURL)/auth/apple") else { throw APIError.invalidURL }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body = AppleAuthRequest(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      name: name,
      email: email
    )
    request.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
    guard (200...299).contains(httpResponse.statusCode) else {
      let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
      throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
    }
    return try JSONDecoder().decode(AppleAuthResponse.self, from: data)
  }

  // NFC (tags are pre-saved in DB; user only verifies scanned tag)
  struct VerifyNFCRequest: Codable { let tagId: String }
  struct VerifyNFCResponse: Codable {
    let success: Bool
    let valid: Bool
    let message: String?
  }

  static func sendOTP(email: String? = nil, phone: String? = nil) async throws -> SendOTPResponse {
    guard let url = URL(string: "\(baseURL)/auth/send-otp") else {
      throw APIError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = SendOTPRequest(email: email, phone: phone)
    request.httpBody = try JSONEncoder().encode(body)
    
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
      }
      
      guard (200...299).contains(httpResponse.statusCode) else {
        let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
        throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
      }

      let decoder = JSONDecoder()
      return try decoder.decode(SendOTPResponse.self, from: data)
    } catch let error as APIError {
      throw error
    } catch {
      throw APIError.networkError(error)
    }
  }
  
  static func verifyOTP(email: String? = nil, phone: String? = nil, otp: String) async throws -> VerifyOTPResponse {
    guard let url = URL(string: "\(baseURL)/auth/verify-otp") else {
      throw APIError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = VerifyOTPRequest(email: email, phone: phone, otp: otp)
    request.httpBody = try JSONEncoder().encode(body)
    
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
      }
      
      guard (200...299).contains(httpResponse.statusCode) else {
        let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
        throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
      }

      let decoder = JSONDecoder()
      return try decoder.decode(VerifyOTPResponse.self, from: data)
    } catch let error as APIError {
      throw error
    } catch {
      throw APIError.networkError(error)
    }
  }

  struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String?
  }

  static func deleteAccount(token: String?) async throws -> DeleteAccountResponse {
    guard let url = URL(string: "\(baseURL)/auth/delete-account") else {
      throw APIError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token = token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
      throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
    }
    return try JSONDecoder().decode(DeleteAccountResponse.self, from: data)
  }

  static func verifyNFCTag(tagId: String, token: String? = nil) async throws -> VerifyNFCResponse {
    guard let url = URL(string: "\(baseURL)/nfc/verify") else { throw APIError.invalidURL }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token = token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(VerifyNFCRequest(tagId: tagId))
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
    guard (200...299).contains(httpResponse.statusCode) else {
      let serverMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
      throw APIError.httpError(httpResponse.statusCode, serverMessage: serverMessage)
    }
    return try JSONDecoder().decode(VerifyNFCResponse.self, from: data)
  }
}
