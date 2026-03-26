import CloudKit
import Foundation

// MARK: - CloudKit Constants

/// Create this container in Xcode Signing & Capabilities → iCloud → CloudKit.
enum CloudKitConstants {
  static let containerIdentifier = "iCloud.dev.ambitionsoftware.tymeboxed"
  static let syncZoneName = "DeviceSync"
}

// MARK: - SyncedProfile

/// CloudKit record for same-user multi-device profile sync (app tokens stay local).
struct SyncedProfile: Codable, Equatable {
  var profileId: UUID
  var name: String
  var createdAt: Date
  var updatedAt: Date

  var blockingStrategyId: String?
  var strategyData: Data?
  var order: Int

  var enableLiveActivity: Bool
  var reminderTimeInSeconds: Int?
  var customReminderMessage: String?
  var enableBreaks: Bool
  var breakTimeInMinutes: Int
  var enableStrictMode: Bool
  var enableAllowMode: Bool
  var enableAllowModeDomains: Bool
  var enableSafariBlocking: Bool
  var preActivationReminderTimesData: Data?

  var physicalUnblockNFCTagId: String?
  var physicalUnblockQRCodeId: String?

  var domains: [String]?

  var scheduleData: Data?
  var geofenceRuleData: Data?

  var startTriggersData: Data?
  var stopConditionsData: Data?
  var startScheduleData: Data?
  var stopScheduleData: Data?
  var startNFCTagId: String?
  var startQRCodeId: String?
  var stopNFCTagId: String?
  var stopQRCodeId: String?

  var disableBackgroundStops: Bool

  var isManaged: Bool
  var managedByChildId: String?

  var lastModified: Date
  var originDeviceId: String
  var version: Int

  var scheduleLastStoppedAt: Date?

  var profileSchemaVersion: Int

  static let recordType = "SyncedProfile"

  enum FieldKey: String {
    case profileId
    case name
    case createdAt
    case updatedAt
    case blockingStrategyId
    case strategyData
    case order
    case enableLiveActivity
    case reminderTimeInSeconds
    case customReminderMessage
    case enableBreaks
    case breakTimeInMinutes
    case enableStrictMode
    case enableAllowMode
    case enableAllowModeDomains
    case enableSafariBlocking
    case preActivationReminderTimesData
    case physicalUnblockNFCTagId
    case physicalUnblockQRCodeId
    case domains
    case scheduleData
    case geofenceRuleData
    case startTriggersData
    case stopConditionsData
    case startScheduleData
    case stopScheduleData
    case startNFCTagId
    case startQRCodeId
    case stopNFCTagId
    case stopQRCodeId
    case disableBackgroundStops
    case isManaged
    case managedByChildId
    case lastModified
    case originDeviceId
    case version
    case profileSchemaVersion
    case scheduleLastStoppedAt
  }

  func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
    let recordID = CKRecord.ID(recordName: profileId.uuidString, zoneID: zoneID)
    let record = CKRecord(recordType: SyncedProfile.recordType, recordID: recordID)
    updateCKRecord(record)
    return record
  }

  func updateCKRecord(_ record: CKRecord) {
    record[FieldKey.profileId.rawValue] = profileId.uuidString
    record[FieldKey.name.rawValue] = name
    record[FieldKey.createdAt.rawValue] = createdAt
    record[FieldKey.updatedAt.rawValue] = updatedAt
    record[FieldKey.blockingStrategyId.rawValue] = blockingStrategyId
    record[FieldKey.strategyData.rawValue] = strategyData
    record[FieldKey.order.rawValue] = order
    record[FieldKey.enableLiveActivity.rawValue] = enableLiveActivity
    record[FieldKey.reminderTimeInSeconds.rawValue] = reminderTimeInSeconds
    record[FieldKey.customReminderMessage.rawValue] = customReminderMessage
    record[FieldKey.enableBreaks.rawValue] = enableBreaks
    record[FieldKey.breakTimeInMinutes.rawValue] = breakTimeInMinutes
    record[FieldKey.enableStrictMode.rawValue] = enableStrictMode
    record[FieldKey.enableAllowMode.rawValue] = enableAllowMode
    record[FieldKey.enableAllowModeDomains.rawValue] = enableAllowModeDomains
    record[FieldKey.enableSafariBlocking.rawValue] = enableSafariBlocking
    record[FieldKey.preActivationReminderTimesData.rawValue] = preActivationReminderTimesData
    record[FieldKey.physicalUnblockNFCTagId.rawValue] = physicalUnblockNFCTagId
    record[FieldKey.physicalUnblockQRCodeId.rawValue] = physicalUnblockQRCodeId
    record[FieldKey.domains.rawValue] = (domains?.isEmpty == false) ? domains : nil
    record[FieldKey.scheduleData.rawValue] = scheduleData
    record[FieldKey.geofenceRuleData.rawValue] = geofenceRuleData
    record[FieldKey.startTriggersData.rawValue] = startTriggersData
    record[FieldKey.stopConditionsData.rawValue] = stopConditionsData
    record[FieldKey.startScheduleData.rawValue] = startScheduleData
    record[FieldKey.stopScheduleData.rawValue] = stopScheduleData
    record[FieldKey.startNFCTagId.rawValue] = startNFCTagId
    record[FieldKey.startQRCodeId.rawValue] = startQRCodeId
    record[FieldKey.stopNFCTagId.rawValue] = stopNFCTagId
    record[FieldKey.stopQRCodeId.rawValue] = stopQRCodeId
    record[FieldKey.disableBackgroundStops.rawValue] = disableBackgroundStops
    record[FieldKey.isManaged.rawValue] = isManaged
    record[FieldKey.managedByChildId.rawValue] = managedByChildId
    record[FieldKey.lastModified.rawValue] = lastModified
    record[FieldKey.originDeviceId.rawValue] = originDeviceId
    record[FieldKey.version.rawValue] = version
    record[FieldKey.profileSchemaVersion.rawValue] = profileSchemaVersion
    record[FieldKey.scheduleLastStoppedAt.rawValue] = scheduleLastStoppedAt
  }

  init?(from record: CKRecord) {
    guard record.recordType == SyncedProfile.recordType,
      let profileIdString = record[FieldKey.profileId.rawValue] as? String,
      let profileId = UUID(uuidString: profileIdString),
      let name = record[FieldKey.name.rawValue] as? String,
      let createdAt = record[FieldKey.createdAt.rawValue] as? Date,
      let updatedAt = record[FieldKey.updatedAt.rawValue] as? Date,
      let lastModified = record[FieldKey.lastModified.rawValue] as? Date,
      let originDeviceId = record[FieldKey.originDeviceId.rawValue] as? String,
      let version = record[FieldKey.version.rawValue] as? Int
    else {
      return nil
    }

    self.profileId = profileId
    self.name = name
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    blockingStrategyId = record[FieldKey.blockingStrategyId.rawValue] as? String
    strategyData = record[FieldKey.strategyData.rawValue] as? Data
    order = record[FieldKey.order.rawValue] as? Int ?? 0
    enableLiveActivity = record[FieldKey.enableLiveActivity.rawValue] as? Bool ?? false
    reminderTimeInSeconds = record[FieldKey.reminderTimeInSeconds.rawValue] as? Int
    customReminderMessage = record[FieldKey.customReminderMessage.rawValue] as? String
    enableBreaks = record[FieldKey.enableBreaks.rawValue] as? Bool ?? false
    breakTimeInMinutes = record[FieldKey.breakTimeInMinutes.rawValue] as? Int ?? 15
    enableStrictMode = record[FieldKey.enableStrictMode.rawValue] as? Bool ?? true
    enableAllowMode = record[FieldKey.enableAllowMode.rawValue] as? Bool ?? false
    enableAllowModeDomains = record[FieldKey.enableAllowModeDomains.rawValue] as? Bool ?? false
    enableSafariBlocking = record[FieldKey.enableSafariBlocking.rawValue] as? Bool ?? true
    preActivationReminderTimesData = record[FieldKey.preActivationReminderTimesData.rawValue] as? Data
    physicalUnblockNFCTagId = record[FieldKey.physicalUnblockNFCTagId.rawValue] as? String
    physicalUnblockQRCodeId = record[FieldKey.physicalUnblockQRCodeId.rawValue] as? String
    domains = record[FieldKey.domains.rawValue] as? [String]
    scheduleData = record[FieldKey.scheduleData.rawValue] as? Data
    geofenceRuleData = record[FieldKey.geofenceRuleData.rawValue] as? Data
    startTriggersData = record[FieldKey.startTriggersData.rawValue] as? Data
    stopConditionsData = record[FieldKey.stopConditionsData.rawValue] as? Data
    startScheduleData = record[FieldKey.startScheduleData.rawValue] as? Data
    stopScheduleData = record[FieldKey.stopScheduleData.rawValue] as? Data
    startNFCTagId = record[FieldKey.startNFCTagId.rawValue] as? String
    startQRCodeId = record[FieldKey.startQRCodeId.rawValue] as? String
    stopNFCTagId = record[FieldKey.stopNFCTagId.rawValue] as? String
    stopQRCodeId = record[FieldKey.stopQRCodeId.rawValue] as? String
    disableBackgroundStops = record[FieldKey.disableBackgroundStops.rawValue] as? Bool ?? false
    isManaged = record[FieldKey.isManaged.rawValue] as? Bool ?? false
    managedByChildId = record[FieldKey.managedByChildId.rawValue] as? String
    self.lastModified = lastModified
    self.originDeviceId = originDeviceId
    self.version = version
    profileSchemaVersion = record[FieldKey.profileSchemaVersion.rawValue] as? Int ?? 1
    scheduleLastStoppedAt = record[FieldKey.scheduleLastStoppedAt.rawValue] as? Date
  }

  init(
    from profile: BlockedProfiles,
    originDeviceId: String
  ) {
    profileId = profile.id
    name = profile.name
    createdAt = profile.createdAt
    updatedAt = profile.updatedAt
    blockingStrategyId = profile.blockingStrategyId
    strategyData = profile.strategyData
    order = profile.order
    enableLiveActivity = profile.enableLiveActivity
    reminderTimeInSeconds = profile.reminderTimeInSeconds
    customReminderMessage = profile.customReminderMessage
    enableBreaks = profile.enableBreaks
    breakTimeInMinutes = profile.breakTimeInMinutes
    enableStrictMode = profile.enableStrictMode
    enableAllowMode = profile.enableAllowMode
    enableAllowModeDomains = profile.enableAllowModeDomains
    enableSafariBlocking = profile.enableSafariBlocking
    preActivationReminderTimesData = nil
    physicalUnblockNFCTagId = profile.physicalUnblockNFCTagId
    physicalUnblockQRCodeId = profile.physicalUnblockQRCodeId
    domains = profile.domains
    disableBackgroundStops = profile.disableBackgroundStops
    isManaged = false
    managedByChildId = nil
    lastModified = Date()
    self.originDeviceId = originDeviceId
    version = profile.syncVersion
    profileSchemaVersion = profile.profileSchemaVersion

    if let schedule = profile.schedule {
      scheduleData = try? JSONEncoder().encode(schedule)
    } else {
      scheduleData = nil
    }

    geofenceRuleData = nil
    startTriggersData = nil
    stopConditionsData = nil
    startScheduleData = nil
    stopScheduleData = nil
    startNFCTagId = nil
    startQRCodeId = nil
    stopNFCTagId = nil
    stopQRCodeId = nil
    scheduleLastStoppedAt = profile.scheduleLastStoppedAt
  }

  var schedule: BlockedProfileSchedule? {
    guard let data = scheduleData else { return nil }
    return try? JSONDecoder().decode(BlockedProfileSchedule.self, from: data)
  }

  var preActivationReminderTimes: [UInt8] {
    guard let data = preActivationReminderTimesData else { return [] }
    return (try? JSONDecoder().decode([UInt8].self, from: data)) ?? []
  }
}

// MARK: - Legacy session cleanup

enum LegacySyncedSession {
  static let recordType = "SyncedSession"
}

// MARK: - Sync reset

struct SyncResetRequest: Codable, Equatable {
  var requestId: UUID
  var clearRemoteAppSelections: Bool
  var requestedAt: Date
  var originDeviceId: String

  static let recordType = "SyncResetRequest"

  enum FieldKey: String {
    case requestId
    case clearRemoteAppSelections
    case requestedAt
    case originDeviceId
  }

  func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
    let recordID = CKRecord.ID(recordName: requestId.uuidString, zoneID: zoneID)
    let record = CKRecord(recordType: SyncResetRequest.recordType, recordID: recordID)

    record[FieldKey.requestId.rawValue] = requestId.uuidString
    record[FieldKey.clearRemoteAppSelections.rawValue] = clearRemoteAppSelections
    record[FieldKey.requestedAt.rawValue] = requestedAt
    record[FieldKey.originDeviceId.rawValue] = originDeviceId

    return record
  }

  init?(from record: CKRecord) {
    guard record.recordType == SyncResetRequest.recordType,
      let requestIdString = record[FieldKey.requestId.rawValue] as? String,
      let requestId = UUID(uuidString: requestIdString),
      let clearRemoteAppSelections = record[FieldKey.clearRemoteAppSelections.rawValue] as? Bool,
      let requestedAt = record[FieldKey.requestedAt.rawValue] as? Date,
      let originDeviceId = record[FieldKey.originDeviceId.rawValue] as? String
    else {
      return nil
    }

    self.requestId = requestId
    self.clearRemoteAppSelections = clearRemoteAppSelections
    self.requestedAt = requestedAt
    self.originDeviceId = originDeviceId
  }

  init(clearRemoteAppSelections: Bool, originDeviceId: String) {
    requestId = UUID()
    self.clearRemoteAppSelections = clearRemoteAppSelections
    requestedAt = Date()
    self.originDeviceId = originDeviceId
  }
}
