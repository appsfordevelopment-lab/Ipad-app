import CoreNFC
import Foundation
import UIKit

/// When an iPhone "Focus session with Break" profile (`NFCPauseTimerBlockingStrategy`) syncs to an iPad
/// without NFC, we run it as **Manual + scheduled breaks** locally. This stores the CloudKit-safe
/// strategy fields so pushes don't overwrite the iPhone with Manual mode.
enum IPadNFCPauseAdaptation {
  private static let suite = UserDefaults.standard
  private static let keyPrefix = "tymeboxed.ipad.nfcpause.canonical."

  struct Canonical: Codable, Equatable {
    var blockingStrategyId: String
    var strategyData: Data?
    var enableBreaks: Bool
    var breakTimeInMinutes: Int
  }

  static func canonical(for profileId: UUID) -> Canonical? {
    guard let data = suite.data(forKey: keyPrefix + profileId.uuidString) else { return nil }
    return try? JSONDecoder().decode(Canonical.self, from: data)
  }

  static func store(canonical: Canonical, for profileId: UUID) {
    guard let data = try? JSONEncoder().encode(canonical) else { return }
    suite.set(data, forKey: keyPrefix + profileId.uuidString)
    suite.synchronize()
  }

  static func clear(for profileId: UUID) {
    suite.removeObject(forKey: keyPrefix + profileId.uuidString)
    suite.synchronize()
  }

  static var shouldAdaptNFCPauseForCurrentDevice: Bool {
    UIDevice.current.userInterfaceIdiom == .pad && !NFCReaderSession.readingAvailable
  }
}
