import Foundation

/// Values driving CloudKit / sync conflict rules. Kept outside `@Model` types so SwiftData
/// schema generation stays stable.
enum TymeBoxedSyncSchema {
  static let currentProfileSchemaVersion = 1
}
