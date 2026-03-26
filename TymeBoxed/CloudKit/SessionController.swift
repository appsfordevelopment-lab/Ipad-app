import Foundation
import SwiftData

/// Defines the contract SyncCoordinator needs for remote session management.
protocol SessionController: AnyObject {
  var activeSession: BlockedProfileSession? { get }
  func startRemoteSession(context: ModelContext, profileId: UUID, sessionId: UUID, startTime: Date)
  func stopRemoteSession(context: ModelContext, profileId: UUID)
}
